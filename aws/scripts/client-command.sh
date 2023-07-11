#! /bin/bash

# sends a command to client

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> CLIENT_COMMAND=<xxx> MNEMONIC=<xxxx>./client-command.sh
#   where PROPOSER_COMMAND mnemonic to get a new mnemonic and zkpd. If MNEMONIC is not empty, it will generate the zkpd for the passed
#   mnemonic
#
#   Run first ping pong test with DELETE_DB=y and USER_DISABLE=y, and then run client-command.sh
#
set -e

COMMAND=$1

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

if [ "$(docker ps | grep client)" ]; then
  CLIENT=$(docker inspect client | grep -m 1 \"IPAddress\" | awk '{print $2}' | tr -d '"|,')
fi
if [ "$(docker ps | grep client-bpw)" ]; then
  CLIENT_BP_WORKER=$(docker inspect client-bpw | grep -m 1 \"IPAddress\" | awk '{print $2}' | tr -d '"|,')
fi
if [ -z "${CLIENT}" ]; then
  CLIENT_API_URL=https://${CLIENT_HOST}
  CLIENT_BP_WORKER_URL=https://${CLIENT_BP_WORKER_HOST}
else
  CLIENT_API_URL=http://${CLIENT}:80
  CLIENT_BP_WORKER_URL=http://${CLIENT_BP_WORKER}
fi

# Using one signing key from ganache user. Doesn't need to be secret
ETHEREUM_SIGNING_KEY='d42905d0582c476c4b74757be6576ec323d715a0c7dcff231b6348b7ab0190eb' \
   MNEMONIC="${MNEMONIC}" \
   CLIENT_API_URL=${CLIENT_API_URL} \
   CLIENT_BP_WORKER_URL=${CLIENT_BP_WORKER_URL} \
  node ../nightfall_3/cli/src/client-command.mjs
