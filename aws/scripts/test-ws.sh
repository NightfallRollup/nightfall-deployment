#! /bin/bash

# Test ws. 
#  - clears the documentDB (optimist data) -> define DELETE_DB to delete document Db
#  - clears the dynamoDB tables  -> define DELETE_DB to delte and create dynamo DB tables
#  - Generates block and transaction data -> define N_TRANSACTIONS to the number of transactions to be created. Default is 4
#  - Writes block and transaction data to documentDb -> define WRITE_DB to write blocks and transactions to document Db
#  - Creates N sockets and requests a sync to EVENT_WS_URL -> define N_SOCKETs to emulate N wallets. Default is 1
#  - Verifies sockets receive data correctly, -> TEST_TYPE is sync of blockProposed
#   subsequent blocks will be received.

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> 
#    LAST_BLOCK=<xxxx> ./test-ws.sh
#      where the starting L2 block number to list
#
#  Examples
#     RELEASE=xxxx N_TRANSACTIONS=100 WRITE_DB=y N_SOCKETS=1000 TEST_TYPE=sync make test-ws
#     RELEASE=xxxx N_TRANSACTIONS=100 WRITE_DB=y N_SOCKETS=1000 TEST_TYPE=syncFast make test-ws
#     RELEASE=xxxx  TEST_TYPE=blockProposed LAST_BLOCK=100 N_SOCKETS=10 make test-ws 
#     RELEASE=preprod TEST_TYPE=syncrollback N_SOCKETS=100 EXPECTED_N_BLOCKS=1 SYNC_TYPE=sync LAST_BLOCK_IN_DB=134 make test-ws
#     RELEASE=preprod TEST_TYPE=rollback LAST_BLOCK=40 N_SOCKETS=1 EXPECTED_N_BLOCKS=1 make test-ws
set -e

# Init tmux pane
init_pane() {
  pane=$1
  # Initialize env vars
  tmux send-keys -t ${pane} 'set -o allexport; \
    source ../env/aws.env; \
    if [ ! -f "../env/${RELEASE}.env" ]; then \
      echo "Undefined RELEASE ${RELEASE};" \
      exit 1; \
    fi; \
    source ../env/${RELEASE}.env; \
    if [[ "${DEPLOYER_ETH_NETWORK}" == "staging"* ]]; then \
      source ../env/secrets-ganache.env; \
    else \
      source ../env/secrets.env; \
    fi; \
    set +o allexport' Enter
}

# Init tmux session
init_tmux(){
  KILL_SESSION=$(tmux ls 2> /dev/null | grep ${WS_SESSION} || true)
  if [ "${KILL_SESSION}" ]; then
     tmux kill-session -t ${WS_SESSION}
  fi
  tmux new -d -s ${WS_SESSION}
  tmux split-window -h

  init_pane ${BLOCKS_PANE}
  init_pane ${WS_PANE}
}

WS_SESSION=${RELEASE}-ws

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

mkdir -p ../test/data

MONGO_USERNAME=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${MONGO_INITDB_ROOT_USERNAME_PARAM}" | jq '.Parameter.Value' | tr -d '"') 
MONGO_PASSWORD=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${MONGO_INITDB_ROOT_PASSWORD_PARAM}" --with-decryption | jq '.Parameter.Value' | tr -d '"') 

# Deletes DB
if [ "${DELETE_DB}" ]; then
  #echo "Restarting publisher"
  ./restart-task.sh publisher
  echo "Deleting Document Db"
  ./delete-db.sh
  ./init-db.sh
fi

if [ -z "${TEST_TYPE}" ]; then
   TEST_TYPE=sync
fi
# Create DynamoDb Tables
if [ "${DELETE_DB}" ]; then
  echo "Deleting Dynamo Db tables"
  ./create-dynamodb.sh
fi

if [ "${TEST_TYPE}" = "sync" ] || [ "${TEST_TYPE}" = "syncFast" ]; then
  # Retrieve number of blocks in docDB
  N_BLOCKS=$(mongosh --host ${MONGO_URL}:27017 \
   --retryWrites=false\
   --username ${MONGO_USERNAME} \
   --password ${MONGO_PASSWORD} \
   --quiet \
   --eval  "db.getMongo().use(\"${OPTIMIST_DB}\");\
     db.${SUBMITTED_BLOCKS_COLLECTION}.find().count();")

  # Generate Data
  if [ "${N_TRANSACTIONS}" ]; then
    echo "Generating ${N_TRANSACTIONS} transactions..."
    cd ../test/publisher && N_TRANSACTIONS=${N_TRANSACTIONS} \
      STARTING_L2_BLOCK=${N_BLOCKS} \
      node generate-data.mjs
  fi
fi

# Check publisher is alive
while true; do
  echo "Waiting for connection with ${PUBLISHER_HOST}..."
  PUBLISHER_RESPONSE=$(curl https://"${PUBLISHER_HOST}"/healthcheck 2> /dev/null | grep OK || true)
  if [ "${PUBLISHER_RESPONSE}" ]; then
    echo "Connected to ${PUBLISHER_HOST}..."
	  break
  fi
  sleep 10
done

if [ "${TEST_TYPE}" = "sync" ] || [ "${TEST_TYPE}" = "syncFast" ]; then
  # Write data
  if [ "${WRITE_DB}" ] && [ "${N_TRANSACTIONS}" ] && [ "${N_TRANSACTIONS}" -gt 0 ]; then
    echo "writing blocks and transactions...."
    cd ../test/publisher && COMMAND=insert \
      MONGO_CONNECTION_STRING=mongodb://${MONGO_INITDB_ROOT_USERNAME}:${MONGO_INITDB_ROOT_PASSWORD}@${MONGO_URL}:27017/?replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false
      node mongo-command.mjs
  fi
  
  # Retrieve number of blocks in docDB
  N_BLOCKS=$(mongosh --host ${MONGO_URL}:27017 \
   --retryWrites=false\
   --username ${MONGO_USERNAME} \
   --password ${MONGO_PASSWORD} \
   --quiet \
   --eval  "db.getMongo().use(\"${OPTIMIST_DB}\");\
     db.${SUBMITTED_BLOCKS_COLLECTION}.find().count();")
fi
  
if [ -z "${LAST_BLOCK}" ]; then
  if [ "${TEST_TYPE}" = "blockProposed" ]; then
    if [ -z "${LAST_BLOCK}" ]; then
      echo "LAST_BLOCK needs to be defined"
    fi
    N_BLOCKS=${LAST_BLOCK}
  else
    LAST_BLOCK=-1
  fi
fi

sleep 1

# Create Sockets and Verify
if [ "${TEST_TYPE}" = "sync" ] || [ "${TEST_TYPE}" = "syncFast"  ]; then
cd ../test/publisher && LAST_BLOCK=${LAST_BLOCK} \
  EVENT_WS_URL=${API_WS_SEND_ENDPOINT} \
  N_SOCKETS=${N_SOCKETS} \
  EXPECTED_N_BLOCKS=${N_BLOCKS} \
  TEST_TYPE=${TEST_TYPE} \
  node web-sockets.mjs;  
elif [ "${TEST_TYPE}" = "syncrollback" ]; then

  if [ -z "${LAST_BLOCK_IN_DB}" ]; then
    LAST_BLOCK_IN_DB=0
  fi
  BLOCKS_TO_DELETE=()
  randomNumber=$(shuf -i 0-${LAST_BLOCK_IN_DB} -n1)
  BLOCKS_TO_DELETE+=(${randomNumber})

  echo ${BLOCKS_TO_DELETE[*]}
  echo ${#BLOCKS_TO_DELETE[@]}

  BLOCKS_PANE=0
  WS_PANE=1
  init_tmux 

  tmux send-keys -t ${WS_PANE} "cd ../test/publisher && LAST_BLOCK=${LAST_BLOCK} \
             EVENT_WS_URL=${API_WS_SEND_ENDPOINT} \
             N_SOCKETS=${N_SOCKETS} \
             EXPECTED_N_BLOCKS=${#BLOCKS_TO_DELETE[@]} \
             TEST_TYPE=${TEST_TYPE} \
             DELETE_BLOCKS='${BLOCKS_TO_DELETE[*]}' \
             SYNC_TYPE=${SYNC_TYPE} \
             node web-sockets.mjs" Enter

  sleep 5
  N_BLOCKS=0

    # Write data
    echo "Write data..."
    cd ../test/publisher && COMMAND=updateAndDelete \
        MONGO_INITDB_ROOT_PASSWORD=${MONGO_PASSWORD}\
        MONGO_INITDB_ROOT_USERNAME=${MONGO_USERNAME}\
        DELETE_BLOCKS=${BLOCKS_TO_DELETE[*]}\
        node mongo-command.mjs
    cd -

    sleep 13
    tmux send-keys -t ${BLOCKS_PANE} 'echo "Block rollback test finished"' Enter
elif [[ "${TEST_TYPE}" = "rollback" ]]; then

  BLOCKS_TO_DELETE=()
  while [ ${#BLOCKS_TO_DELETE[@]} -lt ${EXPECTED_N_BLOCKS} ]; do
    randomNumber=$(shuf -i 0-${LAST_BLOCK} -n1)
    if [[ ! " ${BLOCKS_TO_DELETE[*]} " =~ " ${randomNumber} " ]]; then
      BLOCKS_TO_DELETE+=(${randomNumber})
    fi
  done
  BLOCKS_TO_DELETE=( $( printf "%s\n" "${BLOCKS_TO_DELETE[@]}" | sort -rn ) )

  echo ${BLOCKS_TO_DELETE[*]}
  echo ${#BLOCKS_TO_DELETE[@]}

  BLOCKS_PANE=0
  WS_PANE=1
  init_tmux 

  tmux send-keys -t ${WS_PANE} "cd ../test/publisher && LAST_BLOCK=${LAST_BLOCK} \
             EVENT_WS_URL=${API_WS_SEND_ENDPOINT} \
             N_SOCKETS=${N_SOCKETS} \
             EXPECTED_N_BLOCKS=${#BLOCKS_TO_DELETE[@]} \
             TEST_TYPE=${TEST_TYPE} \
             DELETE_BLOCKS='${BLOCKS_TO_DELETE[*]}' \
             node web-sockets.mjs" Enter

  sleep 5
  N_BLOCKS=0

    # Write data
    echo "Write data..."
    cd ../test/publisher && COMMAND=updateAndDelete \
        MONGO_INITDB_ROOT_PASSWORD=${MONGO_PASSWORD}\
        MONGO_INITDB_ROOT_USERNAME=${MONGO_USERNAME}\
        DELETE_BLOCKS=${BLOCKS_TO_DELETE[*]}\
        node mongo-command.mjs
    cd -

    sleep 13
    tmux send-keys -t ${BLOCKS_PANE} 'echo "Block rollback test finished"' Enter
else
  BLOCKS_PANE=0
  WS_PANE=1
  init_tmux 

  tmux send-keys -t ${WS_PANE} "cd ../test/publisher && LAST_BLOCK=${LAST_BLOCK} \
             EVENT_WS_URL=${API_WS_SEND_ENDPOINT} \
             N_SOCKETS=${N_SOCKETS} \
             EXPECTED_N_BLOCKS=${LAST_BLOCK} \
             TEST_TYPE=${TEST_TYPE} \
             node web-sockets.mjs" Enter

  sleep 5
  N_BLOCKS=0
  while [ ${LAST_BLOCK} -gt 0 ]; do
    # Random blocks between 1 and 10
    RANDOM_BLOCKS=$((45 + $RANDOM % 1))
            
    # Generate Data
    echo "Generating ${RANDOM_BLOCKS} blocks starting at ${N_BLOCKS}"
    TRANSACTIONS_PER_BLOCK=4
    cd ../test/publisher && N_TRANSACTIONS=$((${TRANSACTIONS_PER_BLOCK}*${RANDOM_BLOCKS})) \
               STARTING_L2_BLOCK=${N_BLOCKS} \
               TRANSACTIONS_PER_BLOCK=${TRANSACTIONS_PER_BLOCK} \
               node generate-data.mjs
    cd -
    N_BLOCKS=$((${N_BLOCKS}+${RANDOM_BLOCKS}))
    tmux send-keys -t ${BLOCKS_PANE} "GENERATED_BLOCKS=${N_BLOCKS}" Enter
  

    # Write data
    echo "Write $((${TRANSACTIONS_PER_BLOCK}*${RANDOM_BLOCKS})) transactions..."
    cd ../test/publisher && COMMAND=insert \
        MONGO_CONNECTION_STRING=mongodb://${MONGO_INITDB_ROOT_USERNAME}:${MONGO_INITDB_ROOT_PASSWORD}@${MONGO_URL}:27017/?replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false
        node mongo-command.mjs
    cd -

    sleep 13

    LAST_BLOCK=$((${LAST_BLOCK}-${RANDOM_BLOCKS}))
  done
  tmux send-keys -t ${BLOCKS_PANE} 'echo "Block proposed test finished"' Enter
fi