#! /bin/bash

#  Waits until MongoDb starts/stops on AWS (blocking)

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./wait-db.sh <start/stop>
#

if  [[ "$#" -ne 1 || ("$1" != "start" && "$1" != "stop") ]]; then
  echo "Usage: AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> ./wait-db.sh <start/stop>"
  echo "EEE $# $1"
  exit 1
fi

if [ "$1" == "start" ]; then
  PREFERRED_STATUS=available
else
  PREFERRED_STATUS=stopped
fi

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

while true; do
  DOCDB_STATUS=$(aws docdb describe-db-clusters --db-cluster-identifier ${MONGO_ID} | jq '.DBClusters[0].Status' | tr -d '"')
  echo "DocDB Status is ${DOCDB_STATUS}"
  if [ "${DOCDB_STATUS}" == "${PREFERRED_STATUS}" ]; then
    break
  fi
  sleep 5
done
