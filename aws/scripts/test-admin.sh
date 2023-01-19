#! /bin/bash

# test contracts

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./test-contract.sh
#   where PROPOSER_COMMAND is deregister or change
#
set -e

# Export env variables
set -o allexport
source ../env/aws.env
if [ ! -f "../env/${RELEASE}.env" ]; then
   echo "Undefined RELEASE ${RELEASE}"
   exit 1
fi
source ../env/${RELEASE}.env
if [ "${DEPLOYER_ETH_NETWORK}" = "staging" ]; then
  SECRETS_ENV=../env/secrets-ganache.env
else
  SECRETS_ENV=../env/secrets.env
fi
source ${SECRETS_ENV}
set +o allexport

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
echo "Retrieving secret /${ENVIRONMENT_NAME}/${BOOT_PROPOSER_KEY_PARAM}"
BOOT_PROPOSER_KEY=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${BOOT_PROPOSER_KEY_PARAM}" --with-decryption | jq '.Parameter.Value' | tr -d '"') 
if [ -z "${BOOT_PROPOSER_KEY}" ]; then
   echo "Could not read parameter..."
   exit 1
fi
echo "Retrieving secret /${ENVIRONMENT_NAME}/${BOOT_PROPOSER_KEY_PARAM}"
BOOT_PROPOSER_KEY=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${BOOT_PROPOSER_KEY_PARAM}" --with-decryption | jq '.Parameter.Value' | tr -d '"') 
if [ -z "${BOOT_PROPOSER_KEY}" ]; then
   echo "Could not read parameter..."
   exit 1
fi
echo "Retrieving secret /${ENVIRONMENT_NAME}/${BOOT_CHALLENGER_KEY_PARAM}"
BOOT_CHALLENGER_KEY=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${BOOT_CHALLENGER_KEY_PARAM}" --with-decryption | jq '.Parameter.Value' | tr -d '"') 
if [ -z "${BOOT_CHALLENGER_KEY}" ]; then
   echo "Could not read parameter..."
   exit 1
fi

echo "Retrieving secret /${ENVIRONMENT_NAME}/${BOOT_PROPOSER_MNEMONIC_PARAM}"
BOOT_PROPOSER_MNEMONIC=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${BOOT_PROPOSER_MNEMONIC_PARAM}" --with-decryption | jq '.Parameter.Value' | tr -d '"') 
if [ -z "${BOOT_PROPOSER_MNEMONIC}" ]; then
   echo "Could not read parameter..."
   exit 1
fi

set +e 
while true; do
  CLIENT=$(docker inspect client | grep -m 1 \"IPAddress\" | awk '{print $2}' | tr -d '"|,')
  if [ "${CLIENT}" ]; then
    HCHECK=$(curl "http://${CLIENT}:80/healthcheck" 2> /dev/null)
    if [ "${HCHECK}" ]; then
      cd ../nightfall_3 && ENVIRONMENT=aws && CLIENT_HOST=${CLIENT} \
        CLIENT_PORT=80 \
        USER1_MNEMONIC=${USER1_MNEMONIC} \
        USER1_KEY=${USER1_KEY} \
        USER2_MNEMONIC=${USER2_MNEMONIC} \
        USER2_KEY=${USER2_KEY} \
        BOOT_PROPOSER_KEY=${BOOT_PROPOSER_KEY} \
        PROPOSER2_KEY=${BOOT_CHALLENGER_KEY} \
        BOOT_PROPOSER_MNEMONIC=${BOOT_PROPOSER_MNEMONIC} \
        npm run test-administrator
      break
    fi
  fi
  sleep 4
done

echo "Stop running containers"
# Stop worker, rabbitmq, client, user1 and user2
WORKER_PROCESS_ID=$(docker ps | grep nightfall-worker | awk '{print $1}' || true)
if [ "${WORKER_PROCESS_ID}" ]; then
  docker stop "${WORKER_PROCESS_ID}"
fi
RABBITMQ_PROCESS_ID=$(docker ps | grep nightfall-rabbitmq | awk '{print $1}' || true)
if [ "${RABBITMQ_PROCESS_ID}" ]; then
  docker stop "${RABBITMQ_PROCESS_ID}"
fi
CLIENT_PROCESS_ID=$(docker ps | grep nightfall-client | awk '{print $1}' || true)
if [ "${CLIENT_PROCESS_ID}" ]; then
  docker stop "${CLIENT_PROCESS_ID}"
fi