#! /bin/bash

#  Launches ping pong test

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxx> ./launch-test.sh
#   where AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are the AWS credentials
#   and RELEASE is the tag for the container image. If not defined, it will be set to latest
#
#  DELETE_DB: delete nightfall commitment collections
#
#  Pre-reqs
#  - Script assumes that a Web3 node in ${BLOCKCHAIN_WS_HOST}:${BLOCKCHAIN_PORT} is running. It will wait 
#   until it can connect to it
#  - Script can only be executed from a server with access to Nightfall private subnet

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

if [ "${TEST}" = "RLN" ]; then
  TEST_FILE=test/rln/rln.test.mjs
else
  TEST_FILE=test/ping-pong-single/ping-pong.test.mjs
fi

# Retrieve User1 secrets from AWS
echo "Retrieving secret /${ENVIRONMENT_NAME}/${USER1_KEY_PARAM}"
USER1_KEY=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${USER1_KEY_PARAM}" --with-decryption | jq '.Parameter.Value' | tr -d '"') 
if [ -z "${USER1_KEY}" ]; then
   echo "Could not read parameter..."
   exit 1
fi
echo "Retrieving secret /${ENVIRONMENT_NAME}/${USER1_MNEMONIC_PARAM}"
USER1_MNEMONIC=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${USER1_MNEMONIC_PARAM}" --with-decryption | jq '.Parameter.Value' | tr -d '"') 
if [ -z "${USER1_MNEMONIC}" ]; then
   echo "Could not read parameter..."
   exit 1
fi
  
# Retrieve User2 secrets from AWS
echo "Retrieving secret /${ENVIRONMENT_NAME}/${USER2_KEY_PARAM}"
USER2_KEY=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${USER2_KEY_PARAM}" --with-decryption | jq '.Parameter.Value' | tr -d '"') 
if [ -z "${USER2_KEY}" ]; then
   echo "Could not read parameter..."
   exit 1
fi
echo "Retrieving secret /${ENVIRONMENT_NAME}/${USER2_MNEMONIC_PARAM}"
USER2_MNEMONIC=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${USER2_MNEMONIC_PARAM}" --with-decryption | jq '.Parameter.Value' | tr -d '"') 
if [ -z "${USER2_MNEMONIC}" ]; then
   echo "Could not read parameter..."
   exit 1
fi

# if there is a local client deployed, use it. Otherwise, use cloud client
CLIENT=$(docker inspect client | grep -m 1 \"IPAddress\" | awk '{print $2}' | tr -d '"|,')
if [ -z "${CLIENT}" ]; then
  if [ "${DELETE_DB}" ]; then
    DB_NAME1=nightfall_commitments
    DB_NAME2=nightfall_commitments2
    echo "Deleting dBs ${DB_NAME1} and ${DB_NAME2}..."

    MONGO_USERNAME=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${MONGO_INITDB_ROOT_USERNAME_PARAM}" | jq '.Parameter.Value' | tr -d '"') 
    MONGO_PASSWORD=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${MONGO_INITDB_ROOT_PASSWORD_PARAM}" --with-decryption | jq '.Parameter.Value' | tr -d '"') 
    mongosh --host ${MONGO_URL}:27017 \
     --username ${MONGO_USERNAME} \
     --password ${MONGO_PASSWORD} \
     --quiet \
     --eval "db.getMongo().use(\"${DB_NAME1}\");  \
         db.dropDatabase(); \
         db.getMongo().use(\"${DB_NAME2}\"); \
         db.dropDatabase();"
    echo "Restarting clients so that they synchronize..."
	  RELEASE=${RELEASE} ./restart-task.sh client
	  RELEASE=${RELEASE} ./stop-service.sh client
	  RELEASE=${RELEASE} ./start-service.sh client
  fi
  while true; do
    CLIENT1_CHECK=$(curl https://"${CLIENT_SERVICE}.${DOMAIN_NAME}"/healthcheck 2> /dev/null | grep OK || true)
    CLIENT2_CHECK=$(curl https://"${CLIENT_SERVICE}2.${DOMAIN_NAME}"/healthcheck 2> /dev/null | grep OK || true)
    WORKER1_CHECK=$(curl https://"${CIRCOM_WORKER_SERVICE}.${DOMAIN_NAME}"/healthcheck 2> /dev/null | grep OK || true)
    WORKER2_CHECK=$(curl https://"${CIRCOM_WORKER_SERVICE}2.${DOMAIN_NAME}"/healthcheck 2> /dev/null | grep OK || true)
    if [[ ("${CLIENT1_CHECK}") && ("${CLIENT2_CHECK}") && ("${WORKER1_CHECK}") && ("${WORKER2_CHECK}") ]]; then
        cd ../nightfall_3 && ENVIRONMENT=aws \
         LAUNCH_LOCAL='' \
         USER1_MNEMONIC=${USER1_MNEMONIC} \
         USER1_KEY=${USER1_KEY} \
         USER2_MNEMONIC=${USER2_MNEMONIC} \
         USER2_KEY=${USER2_KEY} \
         USER1_COMPRESSED_ZKP_PUBLIC_KEY=${USER1_COMPRESSED_ZKP_PUBLIC_KEY} \
         USER2_COMPRESSED_ZKP_PUBLIC_KEY=${USER2_COMPRESSED_ZKP_PUBLIC_KEY} \
         RLN_TOKEN_ADDRESS=${RLN_TOKEN_ADDRESS} \
         npx hardhat test --bail --no-compile ${TEST_FILE}
    fi
    echo "Connecting to clients..."
    sleep 4
  done
else
  while true; do
    CLIENT=$(docker inspect client | grep -m 1 \"IPAddress\" | awk '{print $2}' | tr -d '"|,')
    if [ "${CLIENT}" ]; then
      HCHECK=$(curl "http://${CLIENT}:80/healthcheck" 2> /dev/null)
      if [ "${HCHECK}" ]; then
        cd ../nightfall_3 && ENVIRONMENT=aws \
         LAUNCH_LOCAL=1 \
         CLIENT_HOST=${CLIENT} \
         CLIENT_PORT=80 \
         USER1_MNEMONIC=${USER1_MNEMONIC} \
         USER1_KEY=${USER1_KEY} \
         USER2_MNEMONIC=${USER2_MNEMONIC} \
         USER2_KEY=${USER2_KEY} \
         USER1_COMPRESSED_ZKP_PUBLIC_KEY=${USER1_COMPRESSED_ZKP_PUBLIC_KEY} \
         USER2_COMPRESSED_ZKP_PUBLIC_KEY=${USER2_COMPRESSED_ZKP_PUBLIC_KEY} \
         RLN_TOKEN_ADDRESS=${RLN_TOKEN_ADDRESS} \
         npx hardhat test --bail --no-compile ${TEST_FILE}
        break
      fi
    fi
    sleep 4
  done
fi

