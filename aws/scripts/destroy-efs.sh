#! /bin/bash

#  Deletes AWS EFS

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> ENV_NAME=<xxx>  REGION=<xxx>./destroy-efs.sh
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

echo -e "\nStart EFS deletion..."

efsName=Nightfall-${ENV_NAME,,}-EFS
# Delete EFS and mount targets
efsId=$(aws efs describe-file-systems \
  --region $REGION \
  | jq ".FileSystems[] | select(.Name==\"${efsName}\") | .FileSystemId"  \
  | tr -d '"')
if [ "${efsId}" ]; then
  mountTargetIds=$(aws efs describe-mount-targets \
    --region $REGION \
    --file-system-id $efsId  \
    | jq '.MountTargets[].MountTargetId' \
    | tr -d '"')
  
  echo -n "Deleting Mount Targets..."
  for mountTargetId in $mountTargetIds; do
    aws efs delete-mount-target \
    --mount-target-id $mountTargetId \
    --region $REGION > /dev/null
  done
  
  while true; do
    mountTargetIds=$(aws efs describe-mount-targets \
      --region $REGION \
      --file-system-id $efsId  \
      | jq '.MountTargets[]' \
      | tr -d '"')
    if [ -z "${mountTargetIds}" ]; then  
      break
    fi
    echo -n "."
    sleep 5
  done
  echo -n "OK"
  
  echo ""
  echo "Deleting EFS File System ${efsId}..."
  aws efs delete-file-system \
   --file-system-id $efsId \
   --region $REGION > /dev/null
  echo ""
fi

# Delete security group
sgId=$(aws ec2 describe-security-groups \
 --region $REGION \
 | jq ".SecurityGroups[] | select(.GroupName==\"${ENV_NAME}-efs-sg\") | .GroupId" \
 | tr -d '"')
if [ "${sgId}" ]; then
  echo "Deleting EFS Security Group..."
  aws ec2 delete-security-group \
   --region $REGION \
   --group-id $sgId > /dev/null
fi
