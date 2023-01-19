#! /bin/bash

# Umounts EFS file system in server.

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./mount-efs.sh
#

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

# Umount EFS
if [ "$(uname)" == "Darwin" ]; then
    # Do something under Mac OS X platform 
   sudo umount -f ${EFS_MOUNT_POINT}
else
   sudo umount -f -l ${EFS_MOUNT_POINT}
fi

rmdir ${EFS_MOUNT_POINT}
