#! /bin/bash

# Test publisher by updating block and transactions collection in DocumentDb and
#  then launching publisher locally. Test passes is update to document db is 
#  updated to dynamoDb 

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> INSERT_DATA=<xxx> 
#   DONT_LAUNCH_PUBLISHER=<xxxx> ./test-publisher.sh
#    If INSERT_DATA is empty, the test will not add new data to DocumentDb
#    If DONT_LAUNCH_PUBLISHER is empty, the test will launch publisher process
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

# Init tmux pane
init_pane() {
  pane=$1
  # we need to login to have access to envs
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
  KILL_SESSION=$(tmux ls 2> /dev/null | grep ${PUBLISHER_SESSION} || true)
  if [ "${KILL_SESSION}" ]; then
     tmux kill-session -t ${PUBLISHER_SESSION}
  fi
  tmux new -d -s ${PUBLISHER_SESSION}
  tmux split-window -h

  init_pane ${MONGODB_PANE}
  init_pane ${PUBLISHER_PANE}
}

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

PUBLISHER_SESSION=${RELEASE}-publisher
MONGODB_PANE=0
PUBLISHER_PANE=1
init_tmux

if [ "${INSERT_DATA}" ]; then
  # Insert some elemements to DocumentDB (blocks and transactions collections)
  tmux send-keys -t ${MONGODB_PANE} "echo 'Initializing transaction collection';
           cd ../test && MONGO_INITDB_ROOT_PASSWORD=${MONGO_INITDB_ROOT_PASSWORD} \
            MONGO_INITDB_ROOT_USERNAME=${MONGO_INITDB_ROOT_USERNAME} \
            COMMAND=initialize \
            sleep 10" Enter
  tmux send-keys -t ${MONGODB_PANE} "for iteration in {1..5}; do \
        echo 'Inserting new blocks....';
        cd ../test && MONGO_INITDB_ROOT_PASSWORD=${MONGO_INITDB_ROOT_PASSWORD} \
            MONGO_INITDB_ROOT_USERNAME=${MONGO_INITDB_ROOT_USERNAME} \
            COMMAND=insert \
            node index.mjs; \
        cd ../test && MONGO_INITDB_ROOT_PASSWORD=${MONGO_INITDB_ROOT_PASSWORD} \
            MONGO_INITDB_ROOT_USERNAME=${MONGO_INITDB_ROOT_USERNAME} \
            COMMAND=insert \
            node index.mjs; \
        sleep 10;
        echo 'Removing 1 block....';
        cd ../test && MONGO_INITDB_ROOT_PASSWORD=${MONGO_INITDB_ROOT_PASSWORD} \
            MONGO_INITDB_ROOT_USERNAME=${MONGO_INITDB_ROOT_USERNAME} \
            COMMAND=delete \
            node index.mjs; \
        sleep 10;
     done" Enter
else
  tmux send-keys -t ${MONGODB_PANE} "echo 'No database insertion requested'"  Enter
  tmux send-keys -t ${MONGODB_PANE} "./connect-db.sh" Enter
fi

if [ -z "${DONT_LAUNCH_PUBLISHER}" ]; then
  tmux send-keys -t ${PUBLISHER_PANE} "cd ../services/publisher && MONGO_INITDB_ROOT_PASSWORD=${MONGO_INITDB_ROOT_PASSWORD} \
    MONGO_INITDB_ROOT_USERNAME=${MONGO_INITDB_ROOT_USERNAME} \
    AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID_VALUE} \
    AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY_VALUE} \
    PUBLISHER_POLLING_INTERVAL_SECONDS=30 \
    PUBLISHER_PORT=9000 \
    node index.mjs" Enter
else
  tmux send-keys -t ${PUBLISHER_PANE} "echo 'Don't launch publisher requested'"  Enter
fi
