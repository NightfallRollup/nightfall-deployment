#! /bin/bash

#  Initialises dynamoDb tables

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxx> ./create-dynamoDb.sh
#   where AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are the AWS credentials
#   and RELEASE is the tag for the container image. If not defined, it will be set to latest
#
set -e  

# Export env variables
set -o allexport
source ../env/aws.env
if [ ! -f "../env/${RELEASE}.env" ]; then
   echo "Undefined RELEASE ${RELEASE}"
   exit 1
fi
source ../env/${RELEASE}.env
if [[ "${DEPLOYER_ETH_NETWORK}" == "staging"* ]]; then
  SECRETS_ENV=../env/secrets-ganache.env
else
  SECRETS_ENV=../env/secrets.env
fi
source ${SECRETS_ENV}
set +o allexport

echo "Create DocumentDB DynamoDB table..."
ALARMS_DOCUMENTDB=$(aws cloudwatch describe-alarms | jq .MetricAlarms[].AlarmName | grep  ${DYNAMODB_DOCUMENTDB_TABLE} | tr -d '"')
for ALARM in ${ALARMS_DOCUMENTDB}; do
  aws cloudwatch delete-alarms --alarm-names ${ALARM}
  sleep 1
done

DOCUMENTDB=$(aws dynamodb describe-table --table-name ${DYNAMODB_DOCUMENTDB_TABLE} --region ${REGION} 2> /dev/null \
  | jq '.Table.TableStatus' \
  | tr -d '\"')
if [ "${DOCUMENTDB}" = "ACTIVE" ]; then
  DOCUMENTDB=$(aws dynamodb delete-table --table-name ${DYNAMODB_DOCUMENTDB_TABLE} --region ${REGION} 2> /dev/null \
  | jq '.TableDescription.TableStatus' \
  | tr -d '\"')
  sleep 2
  if [ "${DOCUMENTDB}" != "DELETING" ]; then
    echo "DynamoDB Table ${DYNAMODB_DOCUMENTDB_TABLE} couldn't be deleted...."
    exit 1
  fi
fi
echo "DynamoDB Table ${DYNAMODB_DOCUMENTDB_TABLE} deleted...."

sleep 5
DOCUMENTDB=$(aws dynamodb create-table \
  --table-name ${DYNAMODB_DOCUMENTDB_TABLE} \
  --attribute-definitions AttributeName=blockType,AttributeType=S \
               AttributeName=blockNumberL2,AttributeType=N \
  --key-schema AttributeName=blockType,KeyType=HASH \
               AttributeName=blockNumberL2,KeyType=RANGE \
  --provisioned-throughput ReadCapacityUnits=${AUTOSCALING_MIN_READ_CAPACITY},WriteCapacityUnits=${AUTOSCALING_MIN_WRITE_CAPACITY} \
  --region ${REGION} 2> /dev/null | jq '.TableDescription.TableStatus' | tr -d '\"')
if [ "${DOCUMENTDB}" != "CREATING" ]; then
  echo "DynamoDB Table ${DYNAMODB_DOCUMENTDB_TABLE} couldn't be created...."
  exit 1
fi
sleep 5

# Enable autoscaling
if [ "${AUTOSCALING_MIN_READ_CAPACITY}" != "${AUTOSCALING_MAX_READ_CAPACITY}" ]; then
  DOCUMENTDB=$(aws application-autoscaling register-scalable-target \
    --service-namespace dynamodb \
    --resource-id "table/${DYNAMODB_DOCUMENTDB_TABLE}" \
    --scalable-dimension "dynamodb:table:ReadCapacityUnits" \
    --region ${REGION} \
    --min-capacity ${AUTOSCALING_MIN_READ_CAPACITY} \
    --max-capacity ${AUTOSCALING_MAX_READ_CAPACITY} 2> /dev/null)

  DOCUMENTDB=$(aws application-autoscaling describe-scalable-targets \
   --service-namespace dynamodb \
   --resource-id "table/${DYNAMODB_DOCUMENTDB_TABLE}" 2> /dev/null)


  aws application-autoscaling put-scaling-policy \
    --service-namespace dynamodb \
    --resource-id "table/${DYNAMODB_DOCUMENTDB_TABLE}" \
    --scalable-dimension "dynamodb:table:ReadCapacityUnits" \
    --policy-name "MyReadScalingPolicy_${DYNAMODB_DOCUMENTDB_TABLE}" \
    --policy-type "TargetTrackingScaling" \
    --region ${REGION} \
    --target-tracking-scaling-policy-configuration file://../aws/lib/policies/dynamo_documentdb_read_policy.json 2> /dev/null
fi

if [ "${AUTOSCALING_MIN_WRITE_CAPACITY}" != "${AUTOSCALING_MAX_WRITE_CAPACITY}" ]; then
  DOCUMENTDB=$(aws application-autoscaling register-scalable-target \
    --service-namespace dynamodb \
    --resource-id "table/${DYNAMODB_DOCUMENTDB_TABLE}" \
    --scalable-dimension "dynamodb:table:WriteCapacityUnits" \
    --region ${REGION} \
    --min-capacity ${AUTOSCALING_MIN_WRITE_CAPACITY} \
    --max-capacity ${AUTOSCALING_MAX_WRITE_CAPACITY} 2> /dev/null)

  DOCUMENTDB=$(aws application-autoscaling describe-scalable-targets \
   --service-namespace dynamodb \
   --resource-id "table/${DYNAMODB_DOCUMENTDB_TABLE}" 2> /dev/null)

  aws application-autoscaling put-scaling-policy \
    --service-namespace dynamodb \
    --resource-id "table/${DYNAMODB_DOCUMENTDB_TABLE}" \
    --scalable-dimension "dynamodb:table:WriteCapacityUnits" \
    --policy-name "MyWriteScalingPolicy_${DYNAMODB_DOCUMENTDB_TABLE}" \
    --policy-type "TargetTrackingScaling" \
    --region ${REGION} \
    --target-tracking-scaling-policy-configuration file://../aws/lib/policies/dynamo_documentdb_write_policy.json 2> /dev/null
fi

echo "DynamoDB Table ${DYNAMODB_DOCUMENTDB_TABLE} created...."


# Web Socket Dynamo Table 
echo "Create WebSocket DynamoDB table..."
ALARMS_WSDB=$(aws cloudwatch describe-alarms | jq .MetricAlarms[].AlarmName | grep  ${DYNAMODB_WS_TABLE} | tr -d '"')
for ALARM in ${ALARMS_WSDB}; do
  aws cloudwatch delete-alarms --alarm-names ${ALARM}
  sleep 1
done
WSDB=$(aws dynamodb describe-table --table-name ${DYNAMODB_WS_TABLE} --region ${REGION} 2> /dev/null \
  | jq '.Table.TableStatus' \
  | tr -d '\"')
if [ "${WSDB}" = "ACTIVE" ]; then
  WSDB=$(aws dynamodb delete-table --table-name ${DYNAMODB_WS_TABLE} --region ${REGION} 2> /dev/null \
  | jq '.TableDescription.TableStatus' \
  | tr -d '\"')
  sleep 2
  if [ "${WSDB}" != "DELETING" ]; then
    echo "DynamoDB Table ${DYNAMODB_WS_TABLE} couldn't be deleted...."
    exit 1
  fi
fi
echo "DynamoDB Table ${DYNAMODB_WS_TABLE} deleted...."

sleep 5
WSDB=$(aws dynamodb create-table \
  --table-name ${DYNAMODB_WS_TABLE} \
  --attribute-definitions AttributeName=connectionID,AttributeType=S \
  --key-schema AttributeName=connectionID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
  --region ${REGION} 2> /dev/null | jq '.TableDescription.TableStatus' | tr -d '\"')
if [ "${WSDB}" != "CREATING" ]; then
  echo "DynamoDB Table ${DYNAMODB_WS_TABLE} couldn't be created...."
  exit 1
fi
echo "DynamoDB Table ${DYNAMODB_WS_TABLE} created...."
