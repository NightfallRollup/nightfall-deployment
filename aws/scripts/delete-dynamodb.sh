#! /bin/bash

#  Deletes dynamoDb tables

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxx> ./delete-dynamoDb.sh
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

# Web Socket Dynamo Table 
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
