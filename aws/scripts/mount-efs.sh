#! /bin/bash

# Mounts EFS file system in server. It is used by deployer

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./mount-efs.sh
#
#  Pre-reqs
#  - Script can only be executed from a server with access to Nightfall private subnet. 

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

# Checl EFS mount point exists
./create-efs-mount-target.sh

mkdir -p ${EFS_MOUNT_POINT}

if [ "$(uname)" == "Darwin" ]; then
    # Do something under Mac OS X platform 
    sudo mount -t nfs -o vers=4 -o tcp -w ${EFS_IP}:/ ${EFS_MOUNT_POINT}
else
   sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${EFS_IP}:/  ${EFS_MOUNT_POINT}
fi

EFS_DRIVE=$(df -h | grep ${EFS_MOUNT_POINT})
sudo mkdir -p ${EFS_MOUNT_POINT}/build
sudo mkdir -p ${EFS_MOUNT_POINT}/build/contracts
sudo mkdir -p ${EFS_MOUNT_POINT}/.openzeppelin
sudo mkdir -p ${EFS_MOUNT_POINT}/proving_files

echo "EFS correctly mounted at ${EFS_MOUNT_POINT}...${EFS_DRIVE}"


