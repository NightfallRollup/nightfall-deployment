#! /bin/bash

# Read dynamoDb table

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> DYNAMODB_TABLE=<xxxx> COMMAND=<xxxx> ./read-dynamoDb.sh 
#   where DYNAMODB_TABLE is the name of the table we want to read.
#   COMMAND is either read or count
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

if [ -z "${DYNAMODB_TABLE}" ]; then
  DYNAMODB_TABLE=${DYNAMODB_DOCUMENTDB_TABLE}
fi

if [ -z "${COMMAND}" ]; then
  COMMAND=read
fi

if [ "${COMMAND}" = "read" ]; then
  DATA=$(aws dynamodb scan --table-name ${DYNAMODB_TABLE} --region ${REGION})
  echo ${DATA} | python3 -m json.tool
else
  COUNT=$(aws dynamodb scan --table-name ${DYNAMODB_TABLE} --region ${REGION} --select "COUNT")
  echo ${COUNT}
fi