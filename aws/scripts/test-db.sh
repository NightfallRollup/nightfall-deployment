#! /bin/bash

# Test db queries

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> COMMAND=<xxxx>
#    LAST_BLOCK=<xxxx> ./test-db.sh
#      where COMMAND is list-blocks and LAST_BLOCK is the starting L2 block number to list
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

AWS_ACCESS_KEY_ID_VALUE=$(aws ssm get-parameter --region ${REGION} --name /${ENVIRONMENT_NAME}/${AWS_ACCESS_KEY_ID_PARAM} \
   | jq '.Parameter.Value' | tr -d '"') 
AWS_SECRET_ACCESS_KEY_VALUE=$(aws ssm get-parameter --region ${REGION} --name /${ENVIRONMENT_NAME}/${AWS_SECRET_ACCESS_KEY_PARAM}  \
   --with-decryption | \
   jq '.Parameter.Value' | tr -d '"') 

cd ../test && MONGO_INITDB_ROOT_PASSWORD=${MONGO_INITDB_ROOT_PASSWORD} \
  MONGO_INITDB_ROOT_USERNAME=${MONGO_INITDB_ROOT_USERNAME} \
  COMMAND=list-blocks \
  LAST_BLOCK=${LAST_BLOCK} \
  node index.mjs; 
