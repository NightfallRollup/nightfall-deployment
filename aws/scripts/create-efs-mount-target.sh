#! /bin/bash

#  Creates a mount target for the EFS for each of the availability zones. Mount targets
#    will provide a usable IP address to use the EFS by other services.

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxxx> ./create-efs-mount-target.sh
#
#  Pre-reqs
#  - Script assumes that a EFS has been already created

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

EFS_INFO=$(aws efs describe-mount-targets \
--file-system-id ${EFS_ID} \
--region ${REGION} | grep OwnerId)

if [ -z "${EFS_INFO}" ]; then
  echo "Creating EFS mount points..."
  # Create Mount Target

  # Subnet 1
  aws efs create-mount-target \
  --file-system-id ${EFS_ID} \
  --subnet-id  ${BACK1_SUBNET_ID} \
  --security-group ${EFS_SG_ID} \
  --region ${REGION} 

  sleep 1

  # Subnet 2
  aws efs create-mount-target \
  --file-system-id ${EFS_ID} \
  --subnet-id  ${BACK2_SUBNET_ID} \
  --security-group ${EFS_SG_ID} \
  --region ${REGION} 

  # Subnet 3
  sleep 1
  aws efs create-mount-target \
  --file-system-id ${EFS_ID} \
  --subnet-id  ${BACK3_SUBNET_ID} \
  --security-group ${EFS_SG_ID} \
  --region ${REGION}

  sleep 1
else
  echo "EFS Target mount points already created..."
  exit 0
fi

EFS_INFO=$(aws efs describe-mount-targets \
--file-system-id ${EFS_ID} \
--region ${REGION} | grep OwnerId)
if [ -z "${EFS_INFO}" ]; then
  echo "Couldn't create EFS mount point.. Exiting"
  exit 1
fi

echo "EFS Target mount points created..."
