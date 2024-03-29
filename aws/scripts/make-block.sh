#! /bin/bash

#  Requests optimist to make a new block whatever the stsate

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./make block

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

# Check optimist is alive
while true; do
  echo "Waiting for connection with ${OPTIMIST_BAWORKER_HOST}..."
  OPTIMIST_RESPONSE=$(curl https://"${OPTIMIST_BA_WORKER_HOST}"/healthcheck 2> /dev/null | grep OK || true)
  if [ "${OPTIMIST_RESPONSE}" ]; then
    echo "Connected to ${OPTIMIST_OPTIMIST_BA_WORKER_HOST}..."
	  break
  fi
  sleep 10
done

curl -X POST https://"${OPTIMIST_BA_WORKER_HOST}"/block/make-now 2> /dev/null 