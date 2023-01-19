#! /bin/bash

#  Launch admin container

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./launch-admin.sh

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

VOLUMES=${PWD}/../volumes/${RELEASE}
mkdir -p ${VOLUMES}/build
# Compare if stored buildin volumes/ are the same than the ones in EFS. If not, copy them
if [ -f ${VOLUMES}/build/hash.txt ]; then
  DIFF=$(cmp ${VOLUMES}/build/hash.txt ${EFS_MOUNT_POINT}/build/hash.txt || true)
  if [ "${DIFF}" ]; then
     echo "New contracts deployed. Copying them to volume"
     sudo cp -R ${EFS_MOUNT_POINT}/build/* ${VOLUMES}/build/
  else
     echo "Contracts are not modified..."
  fi
else
     echo "New contracts deployed. Copying them to volume"
     sudo cp -R ${EFS_MOUNT_POINT}/build/* ${VOLUMES}/build/
fi

echo "Stop running container"
# Stop admin container
ADMIN_PROCESS_ID=$(docker ps | grep nightfall-admin | awk '{print $1}' || true)
if [ "${ADMIN_PROCESS_ID}" ]; then
  docker stop "${ADMIN_PROCESS_ID}"
fi

docker run --rm -d --name nightfall-admin \
   -v ${VOLUMES}/build:/app/build \
   -e ETH_NETWORK=${DEPLOYER_ETH_NETWORK} \
   -e BLOCKCHAIN_WS_HOST=${BLOCKCHAIN_WS_HOST} \
   -e BLOCKCHAIN_URL=wss://${BLOCKCHAIN_WS_HOST}${BLOCKCHAIN_PATH} ${ECR_REPO}/nightfall-admin:${RELEASE}


