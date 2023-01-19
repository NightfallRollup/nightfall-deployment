#! /bin/bash

#  Creates new AWS document db cluster

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> ENV_NAME=<xxx>  REGION=<xxx> ./create-db.sh
#   where AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are the AWS credentials
#   ENV_NAME is the environment to be created
#   REGION is the AWS region where environment is to be created

if [ -z "${ENV_NAME}" ]; then
  echo "Invalid Env name. Exiting..."
  exit 1
fi
if [ -z "${REGION}" ]; then
  echo "Invalid Region. Exiting..."
  exit 1
fi

# Export env variables
set -o allexport
source ../env/init-env.env 
source ../env/secrets-ganache.env

vpcId=$(aws ec2 describe-vpcs \
  --region $REGION \
  | jq ".Vpcs[] | select(.CidrBlock==\"10.48.0.0/16\") | .VpcId" \
  | tr -d '"')

if [ -z "${vpcId}" ]; then
  echo "Couldn't read VPC ID. Exiting..."
  echo 1
fi

subnetIds=()

echo -e "\ndocDb initialization..."

docDbId=docdb-${ENV_NAME,,}1

dbClusterStatus=$(aws docdb describe-db-clusters \
  --region $REGION  \
  | jq ".DBClusters[] | select(.DBClusterIdentifier==\"${docDbId}\")")
if [ "${dbClusterStatus}" ]; then
  echo "docDb Cluster ${docDbId} already exists. Exiting..."
  exit 1
fi

dbInstanceStatus=$(aws docdb describe-db-instances \
  --region $REGION  \
  | jq ".DBInstances[] | select(.DBInstanceIdentifier==\"${docDbId}\")")
if [ "${dbInstanceStatus}" ]; then
  echo "docDb Instance ${docDbId} already exists. Exiting..."
  exit 1
fi

docDbSgName=${ENV_NAME}-docDb-sg
echo "Creating docDb Security Group ${docDbSgName}..."
# Create doc Db Security Group
aws ec2 create-security-group \
--region ${REGION} \
--group-name ${docDbSgName} \
--description ${docDbSgName} \
--vpc-id ${vpcId} > /dev/null
sgId=$(aws ec2 describe-security-groups \
 --region ${REGION} \
 | jq ".SecurityGroups[] | select(.GroupName==\"${ENV_NAME}-docDb-sg\") | .GroupId" \
 | tr -d '"')
if [ -z "${sgId}" ]; then
  echo "Couldnt greate Security Group ${docDbSgName}. Exiting..."
  exit 1
fi
sleep 5
echo "Adding Ingress Rule to ${docDbSgName}..."
aws ec2 authorize-security-group-ingress \
--group-id ${sgId} \
--protocol tcp \
--port 27017 \
--cidr 10.48.0.0/16 \
--region ${REGION} > /dev/null

# create docDb cluster
for index in ${!subNetPrivateCidrBlocks[@]}; do
   cidrBlock=${subNetPrivateCidrBlocks[$index]}

   subnetId=$(aws ec2 describe-subnets  \
    --region ${REGION} \
    --filters "Name=vpc-id,Values=${vpcId}" \
     | jq ".Subnets[] | select(.CidrBlock==\"${cidrBlock}\") |  .SubnetId"   | 
     tr -d '"')
   subnetIds+=(${subnetId})
done

docDbSubnetGroupName=${ENV_NAME,,}-subnet-group
echo "Creating docDb Subnet Group ${docDbSubnetGroupName}..."
aws rds create-db-subnet-group \
  --db-subnet-group-name ${docDbSubnetGroupName} \
  --db-subnet-group-description ${docDbSubnetGroupName} \
  --subnet-ids "[\"${subnetIds[0]}\",\"${subnetIds[1]}\",\"${subnetIds[2]}\"]"  \
  --region ${REGION} > /dev/null

docDbParamsGroupName=docdb-${ENV_NAME,,}1-params
echo "Creating docDb Params Group ${docDbParamsGroupName}..."
aws docdb create-db-cluster-parameter-group \
  --db-cluster-parameter-group-name ${docDbParamsGroupName} \
  --db-parameter-group-family docdb4.0 \
  --description "${ENV_NAME,,} docdb4.0 parameter group" \
  --region $REGION > /dev/null

echo "Setting log retention duration on ${docDbParamsGroupName}..."
aws docdb modify-db-cluster-parameter-group \
       --db-cluster-parameter-group-name ${docDbParamsGroupName} \
       --parameters "ParameterName"=change_stream_log_retention_duration,"ParameterValue"=604800,"ApplyMethod"=pending-reboot \
       --region $REGION > /dev/null
echo "Disabling TLS on ${docDbParamsGroupName}..."
aws docdb modify-db-cluster-parameter-group \
       --db-cluster-parameter-group-name ${docDbParamsGroupName} \
       --parameters "ParameterName"=tls,"ParameterValue"=disabled,"ApplyMethod"=pending-reboot \
       --region $REGION > /dev/null

# Retrieve mongo db user and pwd
MONGO_USER=$(aws ssm get-parameter \
 --region ${REGION} \
 --name "/${ENV_NAME}/${MONGO_INITDB_ROOT_USERNAME_PARAM}" \
 | jq '.Parameter.Value' | tr -d '"') 

MONGO_PWD=$(aws ssm get-parameter  \
 --region ${REGION} \
 --name "/${ENV_NAME}/${MONGO_INITDB_ROOT_PASSWORD_PARAM}" \
 --with-decryption \
 | jq '.Parameter.Value' | tr -d '"') 

echo -n "Creating docDb Cluster ${docDbId}..."
aws docdb create-db-cluster \
  --availability-zones ${REGION}a \
  --db-cluster-identifier ${docDbId} \
  --region $REGION  \
  --engine docdb \
  --engine-version 4.0.0 \
  --vpc-security-group-ids $sgId \
  --db-cluster-parameter-group-name ${docDbParamsGroupName} \
  --db-subnet-group-name ${docDbSubnetGroupName} \
  --master-username ${MONGO_USER} \
  --master-user-password ${MONGO_PWD} > /dev/null

sleep 5
while true; do
  status=$(aws docdb describe-db-clusters \
    --region $REGION \
    --db-cluster-identifier ${docDbId} \
    | jq '.DBClusters[] | select(.Status=="available")')
  if [ "${status}" ]; then
    break
  fi
  echo -n "." 
  sleep 5
done
echo -n "OK"

echo ""
echo -n "Creating docDb Instance ${docDbId}..."
aws docdb create-db-instance \
 --db-instance-identifier ${docDbId} \
 --db-instance-class db.r6g.large \
 --region $REGION \
 --db-cluster-identifier docdb-${ENV_NAME,,}1 \
 --engine docdb > /dev/null

sleep 5
 while true; do
  status=$(aws docdb describe-db-instances \
    --region $REGION \
    --db-instance-identifier ${docDbId} \
    | jq '.DBInstances[] | select(.DBInstanceStatus=="available")')
  if [ "${status}" ]; then
    break
  fi
  echo -n "." 
  sleep 5
done
echo -n "OK"
echo ""
