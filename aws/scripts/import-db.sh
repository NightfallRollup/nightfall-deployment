#! /bin/bash

#  import MongoDb collection

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./import-db.sh
#  CLIENT_DB: if non-empty, access client DB
#  DELETE_DB: if non-empty, deletes collection before writing it
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

if [ -z ${CLIENT_DB} ]; then
  MONGO_USERNAME=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${MONGO_INITDB_ROOT_USERNAME_PARAM}" | jq '.Parameter.Value' | tr -d '"') 
  MONGO_PASSWORD=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${MONGO_INITDB_ROOT_PASSWORD_PARAM}" --with-decryption | jq '.Parameter.Value' | tr -d '"') 

  if [ ${DELETE_DB} ]; then
    mongosh --host ${MONGO_URL}:27017 \
     --username="${MONGO_USERNAME}" \
     --password="${MONGO_PASSWORD}" \
     --quiet \
     --eval "db.getMongo().use(\"${DB_NAME}\");db.${COLLECTION_NAME}.drop();"
  fi

  mongoimport --host="${MONGO_URL}:27017" \
   --username="${MONGO_USERNAME}" \
   --password="${MONGO_PASSWORD}" \
   --collection="${COLLECTION_NAME}" \
   --db="${DB_NAME}" \
   --file="../volumes/${RELEASE}/collections/${COLLECTION_NAME}.json"
else
  CLIENT=$(docker inspect client | grep -m 1 \"IPAddress\" | awk '{print $2}' | tr -d '"|,')

  if [ ${DELETE_DB} ]; then
    mongosh --host ${CLIENT}:27017 \
     --quiet \
     --eval "db.getMongo().use(\"${DB_NAME}\");db.${COLLECTION_NAME}.drop();"
  fi

  mongoimport --host="${CLIENT}:27017" \
   --collection="${COLLECTION_NAME}" \
   --db="${DB_NAME}" \
   --file="../volumes/${RELEASE}/collections/${COLLECTION_NAME}.json"
fi