#! /bin/bash

#  Starts MongoDb on AWS (non blocking)

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./start-db.sh
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

DOCDB_STATUS=$(aws docdb describe-db-clusters --db-cluster-identifier ${MONGO_ID} | jq '.DBClusters[0].Status' | tr -d '"')

if [ "${DOCDB_STATUS}" == "stopped" ]; then
  aws docdb start-db-cluster --db-cluster-identifier ${MONGO_ID} > /dev/null
else
  echo "DocDb status is ${DOCDB_STATUS}"
fi
