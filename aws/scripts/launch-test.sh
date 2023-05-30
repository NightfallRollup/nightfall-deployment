#! /bin/bash

#  Launches ping pong test

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxx> ./launch-test.sh
#   where AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are the AWS credentials
#   and RELEASE is the tag for the container image. If not defined, it will be set to latest
#
#  DELETE_DB: delete nightfall commitment collections
#
#  Pre-reqs
#  - Script assumes that a Web3 node in ${BLOCKCHAIN_WS_HOST}:${BLOCKCHAIN_PORT} is running. It will wait 
#   until it can connect to it
#  - Script can only be executed from a server with access to Nightfall private subnet

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

if [ "${TEST}" = "RLN" ]; then
  TEST_FILE=test/rln/rln.test.mjs
elif [ "${TEST}" = "PING_PONG" ]; then
  TEST_FILE=test/ping-pong-single/ping-pong.test.mjs
elif [ "${TEST}" = "OPT_TXW" ]; then
  TEST_FILE=test/tx-worker.test.mjs
elif [ "${TEST}" = "LOAD" ]; then
  TEST_FILE=test/load.test.mjs
else
  echo "No valid test. Exiting...."
  exit 1
fi

# Retrieve User1 secrets from AWS
echo "Retrieving secret /${ENVIRONMENT_NAME}/${USER1_KEY_PARAM}"
USER1_KEY=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${USER1_KEY_PARAM}" --with-decryption | jq '.Parameter.Value' | tr -d '"') 
if [ -z "${USER1_KEY}" ]; then
   echo "Could not read parameter..."
   exit 1
fi
echo "Retrieving secret /${ENVIRONMENT_NAME}/${USER1_MNEMONIC_PARAM}"
USER1_MNEMONIC=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${USER1_MNEMONIC_PARAM}" --with-decryption | jq '.Parameter.Value' | tr -d '"') 
if [ -z "${USER1_MNEMONIC}" ]; then
   echo "Could not read parameter..."
   exit 1
fi
  
# Retrieve User2 secrets from AWS
echo "Retrieving secret /${ENVIRONMENT_NAME}/${USER2_KEY_PARAM}"
USER2_KEY=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${USER2_KEY_PARAM}" --with-decryption | jq '.Parameter.Value' | tr -d '"') 
if [ -z "${USER2_KEY}" ]; then
   echo "Could not read parameter..."
   exit 1
fi
echo "Retrieving secret /${ENVIRONMENT_NAME}/${USER2_MNEMONIC_PARAM}"
USER2_MNEMONIC=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${USER2_MNEMONIC_PARAM}" --with-decryption | jq '.Parameter.Value' | tr -d '"') 
if [ -z "${USER2_MNEMONIC}" ]; then
   echo "Could not read parameter..."
   exit 1
fi

MONGO_USERNAME=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${MONGO_INITDB_ROOT_USERNAME_PARAM}" | jq '.Parameter.Value' | tr -d '"') 
MONGO_PASSWORD=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${MONGO_INITDB_ROOT_PASSWORD_PARAM}" --with-decryption | jq '.Parameter.Value' | tr -d '"') 

# if there is a local client deployed, use it. Otherwise, use cloud client
CLIENT=$(docker inspect client | grep -m 1 \"IPAddress\" | awk '{print $2}' | tr -d '"|,')
if [ -z "${CLIENT}" ]; then
  if [ "${DELETE_DB}" ]; then
    DB_NAME1=nightfall_commitments
    DB_NAME2=nightfall_commitments2
    echo "Deleting dBs ${DB_NAME1} and ${DB_NAME2}..."

    mongosh --host ${MONGO_URL}:27017 \
     --username ${MONGO_USERNAME} \
     --password ${MONGO_PASSWORD} \
     --quiet \
     --eval "db.getMongo().use(\"${DB_NAME1}\");  \
         db.dropDatabase(); \
         db.getMongo().use(\"${DB_NAME2}\"); \
         db.dropDatabase();"
    echo "Restarting clients so that they synchronize..."
	  RELEASE=${RELEASE} ./restart-task.sh client
	  RELEASE=${RELEASE} ./stop-service.sh client
	  RELEASE=${RELEASE} ./start-service.sh client

    if [ "${NIGHTFALL_LEGACY}" != "true" ]; then
	    RELEASE=${RELEASE} ./restart-task.sh client_txw
	    RELEASE=${RELEASE} ./stop-service.sh clienttxw
	    RELEASE=${RELEASE} NEW_DESIRED_COUNT=${CLIENT_TX_WORKER} ./start-service.sh clienttxw

	    RELEASE=${RELEASE} ./restart-task.sh client_bpw
	    RELEASE=${RELEASE} ./stop-service.sh clientbpw
	    RELEASE=${RELEASE} ./start-service.sh clientbpw
    fi
  fi
  
  ### Set cluster variables
  _CLUSTER=${CLUSTER}
  if [ "${CLUSTER}" ]; then
    _CLUSTER="${CLUSTER^^}_"
  fi

  set -o allexport
  CLUSTER=${CLUSTER} ./create-cluster-envfile.sh
  source ../env/cluster.env
  set +o allexport

  while true; do
    CLIENT1_CHECK=$(curl https://"${CLIENT_SERVICE}.${DOMAIN_NAME}"/healthcheck 2> /dev/null | grep OK || true)
    CLIENT2_CHECK=$(curl https://"${_CLIENT_HOST}"/healthcheck 2> /dev/null | grep OK || true)
    if [ "${NIGHTFALL_LEGACY}" != "true" ]; then
      CLIENT1_TXW_CHECK=$(curl https://"${CLIENT_TX_WORKER_SERVICE}.${DOMAIN_NAME}"/healthcheck 2> /dev/null | grep OK || true)
      CLIENT2_TXW_CHECK=$(curl https://"${_CLIENT_TX_WORKER_HOST}"/healthcheck 2> /dev/null | grep OK || true)
      CLIENT1_BPW_CHECK=$(curl https://"${CLIENT_BP_WORKER_SERVICE}.${DOMAIN_NAME}"/healthcheck 2> /dev/null | grep OK || true)
      CLIENT2_BPW_CHECK=$(curl https://"${_CLIENT_BP_WORKER_T}"/healthcheck 2> /dev/null | grep OK || true)
    else
      CLIENT1_TXW_CHECK=1
      CLIENT2_TXW_CHECK=1
      CLIENT1_BPW_CHECK=1
      CLIENT2_BPW_CHECK=1
    fi
    WORKER1_CHECK=$(curl https://"${CIRCOM_WORKER_SERVICE}.${DOMAIN_NAME}"/healthcheck 2> /dev/null | grep OK || true)
    WORKER2_CHECK=$(curl https://"${_CIRCOM_WORKER_HOST}"/healthcheck 2> /dev/null | grep OK || true)
    MONGO_CONNECTION_STRING="mongodb://${MONGO_USERNAME}:${MONGO_PASSWORD}@${MONGO_URL}:27017/?replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
    #if [[ ("${CLIENT1_CHECK}") && ("${CLIENT2_CHECK}") && ("${WORKER1_CHECK}") && ("${WORKER2_CHECK}") ]]; then
    if [[ ("${CLIENT1_CHECK}") && ("${WORKER1_CHECK}") && ("${CLIENT1_TXW_CHECK}") && (${CLIENT1_BPW_CHECK}) ]]; then
        cd ../nightfall_3 && ENVIRONMENT=aws \
         LAUNCH_LOCAL='' \
         CLIENT2_CHECK=${CLIENT2_CHECK} \
         USER1_MNEMONIC=${USER1_MNEMONIC} \
         USER1_KEY=${USER1_KEY} \
         USER2_MNEMONIC=${USER2_MNEMONIC} \
         USER2_KEY=${USER2_KEY} \
         USER1_COMPRESSED_ZKP_PUBLIC_KEY=${USER1_COMPRESSED_ZKP_PUBLIC_KEY} \
         USER2_COMPRESSED_ZKP_PUBLIC_KEY=${USER2_COMPRESSED_ZKP_PUBLIC_KEY} \
         MONGO_INITDB_ROOT_USERNAME=${MONGO_USERNAME} \
         MONGO_INITDB_ROOT_PASSWORD=${MONGO_PASSWORD}  \
         MONGO_CONNECTION_STRING="${MONGO_CONNECTION_STRING}" \
         RLN_TOKEN_ADDRESS=${RLN_TOKEN_ADDRESS} \
         CLIENT2_HOST=https://${_CLIENT_HOST} \
         CLIENT2_TX_WORKER_HOST=https://${_CLIENT_TX_WORKER_HOST} \
         CLIENT2_BP_WORKER_HOST=https://${_CLIENT_BP_WORKER_HOST} \
         npx hardhat test --bail --no-compile ${TEST_FILE}
        break
    fi
    echo "Connecting to clients..."
    sleep 4
  done
else
  MONGO_CONNECTION_STRING="mongodb://${MONGO_USERNAME}:${MONGO_PASSWORD}@${MONGO_URL}:27017/?replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
  while true; do
    CLIENT=$(docker inspect client | grep -m 1 \"IPAddress\" | awk '{print $2}' | tr -d '"|,')
    CLIENT_TX_WORKER=$(docker inspect client-txw | grep -m 1 \"IPAddress\" | awk '{print $2}' | tr -d '"|,')
    CLIENT_BP_WORKER=$(docker inspect client-bpw | grep -m 1 \"IPAddress\" | awk '{print $2}' | tr -d '"|,')
    if [ "${CLIENT}" ]; then
      HCHECK=$(curl "http://${CLIENT}:80/healthcheck" 2> /dev/null)
      if [ "${HCHECK}" ]; then
        cd ../nightfall_3 && ENVIRONMENT=aws \
         LAUNCH_LOCAL=1 \
         CLIENT_HOST=${CLIENT} \
         CLIENT_URL=http://${CLIENT} \
         CLIENT_TX_WORKER_URL=http://${CLIENT_TX_WORKER} \
         CLIENT_BP_WORKER_URL=http://${CLIENT_BP_WORKER} \
         CLIENT_PORT=80 \
         USER1_MNEMONIC=${USER1_MNEMONIC} \
         USER1_KEY=${USER1_KEY} \
         USER2_MNEMONIC=${USER2_MNEMONIC} \
         USER2_KEY=${USER2_KEY} \
         USER1_COMPRESSED_ZKP_PUBLIC_KEY=${USER1_COMPRESSED_ZKP_PUBLIC_KEY} \
         USER2_COMPRESSED_ZKP_PUBLIC_KEY=${USER2_COMPRESSED_ZKP_PUBLIC_KEY} \
         RLN_TOKEN_ADDRESS=${RLN_TOKEN_ADDRESS} \
         MONGO_INITDB_ROOT_USERNAME=${MONGO_USERNAME} \
         MONGO_INITDB_ROOT_PASSWORD=${MONGO_PASSWORD}  \
         MONGO_CONNECTION_STRING="${MONGO_CONNECTION_STRING}" \
         npx hardhat test --bail --no-compile ${TEST_FILE}
        break
      fi
    fi
    sleep 4
  done
fi

