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
if [[ "${DEPLOYER_ETH_NETWORK}" == "staging"* ]]; then
  SECRETS_ENV=../env/secrets-ganache.env
else
  SECRETS_ENV=../env/secrets.env
fi
source ${SECRETS_ENV}
set +o allexport


BOOT_CHALLENGER_KEY=$(aws ssm get-parameter --region ${REGION} --name /${ENVIRONMENT_NAME}/${BOOT_CHALLENGER_KEY_PARAM} \
   --with-decryption | \
   jq '.Parameter.Value' | tr -d '"') 
BOOT_CHALLENGER_MNEMONIC=$(aws ssm get-parameter --region ${REGION} --name /${ENVIRONMENT_NAME}/${BOOT_CHALLENGER_MNEMONIC_PARAM} \
   --with-decryption | \
   jq '.Parameter.Value' | tr -d '"') 

USER_KEY=$(aws ssm get-parameter --region ${REGION} --name /${ENVIRONMENT_NAME}/${USER1_KEY_PARAM} \
   --with-decryption | \
   jq '.Parameter.Value' | tr -d '"') 
USER_MNEMONIC=$(aws ssm get-parameter --region ${REGION} --name /${ENVIRONMENT_NAME}/${USER1_MNEMONIC_PARAM} \
   --with-decryption | \
   jq '.Parameter.Value' | tr -d '"') 

set +e 
while true; do
  CLIENT=$(docker inspect client | grep -m 1 \"IPAddress\" | awk '{print $2}' | tr -d '"|,')
  if [ "${CLIENT}" ]; then
    HCHECK=$(curl "http://${CLIENT}:80/healthcheck" 2> /dev/null)
    if [ "${HCHECK}" ]; then
      cd ../nightfall_3 && CLIENT_API_URL=http://${CLIENT}:80 \
      BOOT_CHALLENGER_KEY=${BOOT_CHALLENGER_KEY} BOOT_CHALLENGER_MNEMONIC=${BOOT_CHALLENGER_MNEMONIC} \
      USER_KEY=${USER_KEY} USER_MNEMONIC=${USER_MNEMONIC} \
      npx hardhat test --bail --no-compile test/contracts-cli/contracts-cli.test.mjs
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