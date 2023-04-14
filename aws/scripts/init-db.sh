#! /bin/bash

#  Initializes MongoDb :
#  - Enables Change streams
#  - Initializes checkpoint
#  - Indexes transactions collection by transaction hash
#  - Indexes blocks collection by blockNumberL2

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./init-db.sh
#
#  OPTIMIST_N: initial number of DBs. Default is 1
#  SINGLE_OPTIMIST: only inititialize this Optimist's Db
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

if [ -z "${OPTIMIST_N}" ]; then  
  OPTIMIST_N=1
fi

if [ "${SINGLE_OPTIMIST}" ]; then
  OPTIMIST_N=${SINGLE_OPTIMIST}
fi

# Enable montitoring TIMBER COLLECTION changes 
#  index transactionHash and transactionHashL1 from TRANSACTIONS_COLLECTION
#  index blockNumberL2, blockHash, blockNumber, proposer and mempool from BLOCKS_COLLECTION
for i in `seq 1 1 ${CLIENT_N}`; do
  if [ ${i} -eq 1 ]; then
    DB_INDEX=
  else
    DB_INDEX=${i}
  fi
  DB_NAME=${COMMITMENTS_DB}${DB_INDEX}
  echo "Indexing ${DB_NAME}..."

  mongosh --host ${MONGO_URL}:27017 \
   --retryWrites=false\
   --username ${MONGO_USERNAME} \
   --password ${MONGO_PASSWORD} \
   --quiet \
   --eval "db.getMongo().use(\"${DB_NAME}\");\
     db.${TRANSACTIONS_COLLECTION}.createIndex({transactionHash:1});\
     db.${SUBMITTED_BLOCKS_COLLECTION}.createIndex({blockNumberL2:-1});\
     db.${SUBMITTED_BLOCKS_COLLECTION}.createIndex({blockHash:-1});\
     db.${SUBMITTED_BLOCKS_COLLECTION}.createIndex({blockNumber:-1});\
     db.${COMMITMENTS_COLLECTION}.createIndex({isNullifiedOnChain:1});\
     db.${COMMITMENTS_COLLECTION}.createIndex({isOnChain:1});\
     db.${COMMITMENTS_COLLECTION}.createIndex({nullifier:1})"
done

COMMAND='$set'
for i in `seq ${SINGLE_OPTIMIST} 1 ${OPTIMIST_N}`; do
  if [ ${i} -eq 1 ]; then
    DB_INDEX=
  else
    DB_INDEX=${i}
  fi
  DB_NAME=${OPTIMIST_DB}${DB_INDEX}
  echo "Monitoring changes Db: ${DB_NAME}, collections: ${TIMBER_COLLECTION} enabled..."

  mongosh --host ${MONGO_URL}:27017 \
   --retryWrites=false\
   --username ${MONGO_USERNAME} \
   --password ${MONGO_PASSWORD} \
   --quiet \
   --eval "db.adminCommand({modifyChangeStreams: 1,database: \"${DB_NAME}\",collection: \"${SUBMITTED_BLOCKS_COLLECTION}\",enable: false}); \
     db.adminCommand({modifyChangeStreams: 1,database: \"${DB_NAME}\",collection: \"${TIMBER_COLLECTION}\",enable: true}); \
     db.adminCommand({modifyChangeStreams: 1,database: \"${DB_NAME}\",collection: '',enable: false}); \
     db.getMongo().use(\"${DB_NAME}\");\
     db.${CHECKPOINT_COLLECTION}.insertOne({_id: 1, checkpoint: 0});\
     db.runCommand( {aggregate: 1, pipeline: [{\$listChangeStreams: 1}], cursor:{}});\
     db.${TRANSACTIONS_COLLECTION}.createIndex({transactionHash:1});\
     db.${TRANSACTIONS_COLLECTION}.createIndex({transactionHashL1:1});\
     db.${TRANSACTIONS_COLLECTION}.createIndex({commitments:1});\
     db.${TRANSACTIONS_COLLECTION}.createIndex({nullifiers:1});\
     db.${TRANSACTIONS_COLLECTION}.createIndex({mempool: -1});\
     db.${TRANSACTIONS_COLLECTION}.createIndex({fee: -1});\
     db.${TIMBER_COLLECTION}.createIndex({blockNumberL2:-1});\
     db.${SUBMITTED_BLOCKS_COLLECTION}.createIndex({blockNumberL2:-1});\
     db.${SUBMITTED_BLOCKS_COLLECTION}.createIndex({blockHash:-1});\
     db.${SUBMITTED_BLOCKS_COLLECTION}.createIndex({blockNumber:-1});\
     db.${SUBMITTED_BLOCKS_COLLECTION}.createIndex({transactionHashes:-1});\
     db.${SUBMITTED_BLOCKS_COLLECTION}.createIndex({proposer: -1})"
     #db.${CHECKPOINT_COLLECTION}.updateOne({_id: 1}, {$COMMAND:{checkpoint: 0}}, upsert=true)"
      
     #db.adminCommand({modifyChangeStreams: 1,database: \"${DB_NAME}\",collection: '',enable: true}); \
   done

#List all databases and collections with change streams enabled
# db.runCommand( {aggregate: 1, pipeline: [{$listChangeStreams: 1}], cursor:{}})
    
