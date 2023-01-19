#! /bin/bash

#  Delete MongoDb

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./connect-db.sh
#
#  Pre-reqs
#  - VPN

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

MONGO_USERNAME=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${MONGO_INITDB_ROOT_USERNAME_PARAM}" | jq '.Parameter.Value' | tr -d '"') 
MONGO_PASSWORD=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${MONGO_INITDB_ROOT_PASSWORD_PARAM}" --with-decryption | jq '.Parameter.Value' | tr -d '"') 

mongosh --host ${MONGO_URL}:27017 \
 --username ${MONGO_USERNAME} \
 --password ${MONGO_PASSWORD} \
 --retryWrites false