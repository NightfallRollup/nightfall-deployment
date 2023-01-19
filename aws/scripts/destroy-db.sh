#! /bin/bash

#  Deletes AWS docDb

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> ENV_NAME=<xxx>  REGION=<xxx>./destroy-db.sh
#   where AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are the AWS credentials
#   ENV_NAME is the environment to be created
#   REGION is the AWS region where environment is to be created

set -e

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

vpcId=$(aws ec2 describe-vpcs \
  --region $REGION \
  | jq ".Vpcs[] | select(.CidrBlock==\"10.48.0.0/16\") | .VpcId" \
  | tr -d '"')

if [ -z "${vpcId}" ]; then
  echo "Couldn't read VPC ID. Exiting..."
  echo 1
fi

docDbId=docdb-${ENV_NAME,,}1
echo -e "\nStart docDb deletion..."
# delete doc db
instanceCreated=$(aws docdb describe-db-instances \
 --region $REGION \
 | jq ".DBInstances[] | select(.DBInstanceIdentifier==\"${docDbId}\")" \
 | tr -d '"')

if [ "${instanceCreated}" ]; then
  echo -n "Waiting for docDb Instance ${docDbId} to be ready..."
  while true; do
    instanceStatus=$(aws docdb describe-db-instances \
      --region $REGION \
      | jq ".DBInstances[] | select(.DBInstanceIdentifier==\"${docDbId}\") | select(.DBInstanceStatus==\"available\")" \
      | tr -d '"')
    if [ "${instanceStatus}" ]; then 
      break
    fi
    echo -n "."
    sleep 5
  done
  echo -n "OK"
  echo ""
  echo -n "Deleting docDb Instance ${docDbId}..."
  aws docdb delete-db-instance \
    --db-instance-identifier ${docDbId} \
    --region ${REGION} > /dev/null
  while true; do
    clusterStatus=$(aws rds describe-db-instances \
     --region $REGION \
     | jq ".DBInstances[] | select(.DBInstanceIdentifier==\"${docDbId}\") | select(.DBInstanceStatus==\"deleting\")" \
     | tr -d '"')
     if [ -z "${clusterStatus}" ]; then
       break
     fi
     echo -n "."
     sleep 5
  done
  echo -n "OK"
fi
echo ""

clusterId=$(aws rds describe-db-clusters \
 --region $REGION \
 | jq ".DBClusters[] | select(.DBClusterIdentifier==\"${docDbId}\") | .DbClusterResourceId" \
 | tr -d '"')

if [ "${clusterId}" ]; then
  echo -n "Waiting for docDb Cluster ${docDbId} to be ready..."
  while true; do
    clusterStatus=$(aws rds describe-db-clusters \
     --region $REGION \
     | jq ".DBClusters[] | select(.DBClusterIdentifier==\"${docDbId}\") | select(.Status==\"available\")" \
     | tr -d '"')
    if [ "${clusterStatus}" ]; then 
      break
    fi
    echo -n "."
    sleep 5
  done
  echo -n "OK"
  echo ""
  echo -n "Deleting docDb Cluster ${docDbId}..."
  aws rds delete-db-cluster \
    --db-cluster-identifier ${docDbId} \
    --skip-final-snapshot \
    --region ${REGION} > /dev/null

  sleep 5
  while true; do
    clusterStatus=$(aws rds describe-db-clusters \
     --region $REGION \
     | jq ".DBClusters[] | select(.DBClusterIdentifier==\"${docDbId}\") | select(.Status==\"deleting\")")
     if [ -z "${clusterStatus}" ]; then
       break
     fi
     echo -n "."
     sleep 5 
  done
  echo -n "OK"
fi
echo ""

echo -n "Waiting for docDb instance ${docDbId} to be deleted..."
while true; do
    clusterStatus=$(aws rds describe-db-instances \
     --region $REGION \
     | jq ".DBInstances[] | select(.DBInstanceIdentifier==\"${docDbId}\") | select(.DBInstanceStatus==\"deleting\")") 
     if [ -z "${clusterStatus}" ]; then
       break
     fi
     echo -n "."
     sleep 5
done
echo ""


echo -n "Waiting for docDb cluster ${docDbId} to be deleted..."
while true; do
  clusterStatus=$(aws rds describe-db-clusters \
   --region $REGION \
   | jq ".DBClusters[] | select(.DBClusterIdentifier==\"${docDbId}\") | select(.Status==\"deleting\")")
   if [ -z "${clusterStatus}" ]; then
     break
   fi
   echo -n "."
   sleep 5 
done
echo ""

docDbParamsGroupName=docdb-${ENV_NAME,,}1-params
paramsGroup=$(aws docdb describe-db-cluster-parameter-groups \
 --region $REGION \
 | jq ".DBClusterParameterGroups[] | select(.DBClusterParameterGroupName==\"${docDbParamsGroupName}\")")
if [ "${paramsGroup}" ]; then
  echo "Deleting paramsGroup ${docDbParamsGroupName}..."
  aws docdb delete-db-cluster-parameter-group \
   --db-cluster-parameter-group-name ${docDbParamsGroupName} \
   --region $REGION > /dev/null
fi

# Delete security group docDb
docDbSgName=${ENV_NAME}-docDb-sg
sgId=$(aws ec2 describe-security-groups \
 --region $REGION \
 | jq ".SecurityGroups[] | select(.GroupName==\"${docDbSgName}\") | .GroupId" \
 | tr -d '"')
if [ ${sgId} ]; then
  echo "Deleting docDb Security Group ${docDbSgName}..."
  aws ec2 delete-security-group \
   --region $REGION \
   --group-id $sgId > /dev/null
fi

# delete subnet group
docDbSubnetGroupName=${ENV_NAME,,}-subnet-group
subnetGroup=$(aws docdb describe-db-subnet-groups \
 --region $REGION \
 | jq ".DBSubnetGroups[] | select(.DBSubnetGroupName==\"${docDbSubnetGroupName}\")")

if [ "${subnetGroup}" ]; then
  echo "Deleting docDb Subgroup ${docDbSubnetGroupName}..."
  aws rds  delete-db-subnet-group \
    --region $REGION \
    --db-subnet-group-name ${docDbSubnetGroupName} > /dev/null
fi

