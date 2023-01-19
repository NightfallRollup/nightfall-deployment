#! /bin/bash

# Test dashboard 

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> DELETE_DB=<zzz> test-dashboard.sh
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

cp ../aws/lib/application/options.js ../services/dashboard/options.js
perl -i -pe's#module.exports.*#export {#g' ../services/dashboard/options.js

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

SLACK_TOKEN_VALUE=$(aws ssm get-parameter --region ${REGION} --name /${ENVIRONMENT_NAME}/${SLACK_TOKEN_PARAM}  \
   --with-decryption | \
   jq '.Parameter.Value' | tr -d '"') 

if [ "${DELETE_DB}" ]; then
  echo "Deleting Doc DB"
  ./delete-db.sh
  ./init-db.sh
fi

cd ../services/dashboard && MONGO_INITDB_ROOT_PASSWORD=${MONGO_INITDB_ROOT_PASSWORD} \
 MONGO_INITDB_ROOT_USERNAME=${MONGO_INITDB_ROOT_USERNAME} \
 AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID_VALUE} \
 AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY_VALUE} \
 DASHBOARD_PORT=9000 \
 DASHBOARD_POLLING_INTERVAL_SECONDS=5 \
 SLACK_TOKEN=${SLACK_TOKEN_VALUE} \
 DASHBOARD_TEST_ENABLE='true' \
 node index.mjs
