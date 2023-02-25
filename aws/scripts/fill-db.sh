#! /bin/bash

# Fill db with random data

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> fill-db.sh
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

MONGO_INITDB_ROOT_PASSWORD=$(aws ssm get-parameter --region ${REGION} --name /${ENVIRONMENT_NAME}/${MONGO_INITDB_ROOT_PASSWORD_PARAM} \
   --with-decryption | \
   jq '.Parameter.Value' | tr -d '"') 
MONGO_INITDB_ROOT_USERNAME=$(aws ssm get-parameter --region ${REGION} --name /${ENVIRONMENT_NAME}/${MONGO_INITDB_ROOT_USERNAME_PARAM}  \
   | jq '.Parameter.Value' | tr -d '"') 

cd ../test/db && MONGO_INITDB_ROOT_PASSWORD=${MONGO_INITDB_ROOT_PASSWORD} \
  MONGO_INITDB_ROOT_USERNAME=${MONGO_INITDB_ROOT_USERNAME} \
  N_TRANSACTIONS=${N_TRANSACTIONS} \
  TRANSACTIONS_PER_BLOCK=${TRANSACTIONS_PER_BLOCK}  \
  node write-workers.mjs;
