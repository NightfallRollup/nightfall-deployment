#! /bin/bash

#  Creates new AWS EFS

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> ENV_NAME=<xxx>  REGION=<xxx>./create-efs.sh
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

vpcId=$(aws ec2 describe-vpcs \
  --region $REGION \
  | jq ".Vpcs[] | select(.CidrBlock==\"10.48.0.0/16\") | .VpcId" \
  | tr -d '"')

if [ -z "${vpcId}" ]; then
  echo "Couldn't read VPC ID. Exiting..."
  echo 1
fi

echo -e "\nEFS initialization..."


efsName=Nightfall-${ENV_NAME,,}-EFS
efsStatus=$(aws efs describe-file-systems \
  --region $REGION \
  | jq ".FileSystems[] | select(.Name==\"${efsName}\")")
if [ "${efsStatus}" ]; then
  echo "EFS ${efsName} already exists. Exiting..."
  exit 1
fi

# Create EFS
echo -n "Creating EFS..."
efs_describe=$(aws efs create-file-system \
  --encrypted \
  --creation-token FileSystemForWalkthrough1 \
  --tags Key=Name,Value=${efsName} \
  --region ${REGION})
efsId=$(echo $efs_describe | jq '.FileSystemId' | tr -d '"')
if [ -z "${efsId}" ]; then
  echo "Couldnt create EFS. Exiting..."
  exit 1
fi 
while true; do
  efsAvailable=$(aws efs describe-file-systems \
    --file-system-id $efsId \
    --region $REGION \
    | jq '.FileSystems[] | select(.LifeCycleState=="available")')
  if [ "${efsAvailable}" ]; then 
    break
  fi
  echo -n "."
  sleep 5
done
echo -n "${efsId}"
echo ""

# Set Backup Policy
echo "Setting Backup Policy..."
aws efs put-backup-policy \
  --file-system-id ${efsId} \
  --region ${REGION} \
  --backup-policy Status="ENABLED" > /dev/null

# Create EFS Security Group
securityGroupName=${ENV_NAME}-efs-sg
echo "Creating Security Group ${securityGroupName}..."
aws ec2 create-security-group \
--region ${REGION} \
--group-name ${securityGroupName} \
--description ${securityGroupName} \
--vpc-id ${vpcId} > /dev/null
sgId=$(aws ec2 describe-security-groups \
 --region ${REGION} \
 | jq ".SecurityGroups[] | select(.GroupName==\"${securityGroupName}\") | .GroupId" \
 | tr -d '"')
if [ -z "${sgId}" ]; then
  echo "Couldnt create Security Group ${securityGroupName}. Exiting..."
  exit 1
fi
sleep 5
echo "Adding Ingress Rule to ${securityGroupName}..."
aws ec2 authorize-security-group-ingress \
--group-id ${sgId} \
--protocol tcp \
--port 2049 \
--cidr 10.48.0.0/16 \
--region ${REGION} > /dev/null

# Add mount target to each private subnet
for index in ${!subNetPrivateCidrBlocks[@]}; do
   cidrBlock=${subNetPrivateCidrBlocks[$index]}
   subnetName=${subNetPrivateNames[$index]}
   echo "Adding Mount Target in ${subnetName}..."

   subnetId=$(aws ec2 describe-subnets  \
    --region ${REGION} \
    --filters "Name=vpc-id,Values=${vpcId}" \
     | jq ".Subnets[] | select(.CidrBlock==\"${cidrBlock}\") |  .SubnetId" \
     | tr -d '"')
   if [ -z "${subnetId}" ]; then
     echo "Couldnt create Mount Target in ${subnetName}. Exiting..."
     exit 1
   fi
   aws efs create-mount-target \
    --file-system-id ${efsId} \
    --subnet-id  ${subnetId} \
    --security-group $sgId \
    --region ${REGION} > /dev/null
done
