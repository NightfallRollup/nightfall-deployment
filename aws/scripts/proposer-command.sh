#! /bin/bash

# sends a command to proposer

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> PROPOSER_COMMAND=<xxx> ./proposer-command.sh
#   where PROPOSER_COMMAND is deregister or change
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

BOOT_PROPOSER_KEY=$(aws ssm get-parameter --region ${REGION} --name /${ENVIRONMENT_NAME}/${BOOT_PROPOSER_KEY_PARAM} \
   --with-decryption | \
   jq '.Parameter.Value' | tr -d '"') 
BOOT_PROPOSER_KEY=${BOOT_PROPOSER_KEY} node ../nightfall_3/cli/src/proposer-command.mjs 