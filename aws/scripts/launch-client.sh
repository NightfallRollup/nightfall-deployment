#! /bin/bash

#  Launches client test

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxx> DELETE_DB=<xxx> USER_DISABLE=<xxx> ./launch-client.sh
#   where AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are the AWS credentials
#   and RELEASE is the tag for the container image. If not defined, it will be set to latest
#   DELETE_DB is a flag to indicate if mondoDb should be deleted. If not empty, DB will be deleted
#
#  Pre-reqs
#  - Script assumes that a Web3 node in ${BLOCKCHAIN_WS_HOST}:${BLOCKCHAIN_PORT} is running. It will wait 
#   until it can connect to it
#  - Script can only be executed from a server with access to Nightfall private subnet

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
    if [[ "${DEPLOYER_ETH_NETWORK}" == "staging"* ]]; then\
      source ../env/secrets-ganache.env; \
    else \
      source ../env/secrets.env; \
    fi; \
    set +o allexport' Enter
}

# Init tmux session
init_tmux(){
  KILL_SESSION=$(tmux ls 2> /dev/null | grep ${CLIENT_SESSION} || true)
  if [ "${KILL_SESSION}" ]; then
     tmux kill-session -t ${CLIENT_SESSION}
  fi
  tmux new -d -s ${CLIENT_SESSION}
  tmux split-window -h
  tmux select-pane -t 0
  tmux split-window -v
  tmux select-pane -t 2
  tmux split-window -v

  init_pane ${WORKER_PANE}
  init_pane ${CLIENT_PANE}
  init_pane ${CLIENT_BPW_PANE}
  init_pane ${CLIENT_TXW_PANE}
}

CLIENT_SESSION=${RELEASE}-client

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

aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_REPO}


# Check Web3 is running
set +e

while true; do
  echo "Waiting for connection with ${BLOCKCHAIN_WS_HOST}..."
  WEB3_RESPONSE=$(curl -f --write-out '%{http_code}' --silent --output output.txt \
    --location --request POST https://"${BLOCKCHAIN_WS_HOST}" \
    --header 'Content-Type: application/json' \
    --data-raw '{
       "jsonrpc":"2.0",
       "method":"eth_blockNumber",
       "params":[],
       "id":83
     }')
  if [ "${WEB3_RESPONSE}" -ge "200" ] && [ "${WEB3_RESPONSE}" -le "499" ]; then
    echo "Connect to ${BLOCKCHAIN_WS_HOST}..."
	  break
  fi
  sleep 10
done
rm -f ./output.txt
set -e

# Check proposer is alive
while true; do
  echo "Waiting for connection with ${PROPOSER_HOST}..."
  PROPOSER_RESPONSE=$(curl https://"${PROPOSER_HOST}"/healthcheck 2> /dev/null | grep OK || true)
  if [ "${PROPOSER_RESPONSE}" ]; then
    echo "Connected to ${PROPOSER_HOST}..."
	  break
  fi
  sleep 10
done

# Check optimist is alive
while true; do
  echo "Waiting for connection with ${OPTIMIST_HTTP_HOST}..."
  OPTIMIST_RESPONSE=$(curl https://"${OPTIMIST_HTTP_HOST}"/contract-address/Shield 2> /dev/null | grep 0x || true)
  if [ "${OPTIMIST_RESPONSE}" ]; then
    echo "Connected to ${OPTIMIST_HTTP_HOST}..."
	  break
  fi
  sleep 10
done

echo "Stop running containers"
# Stop worker, rabbitmq, client, user1 and user2
WORKER_PROCESS_ID=$(docker ps | grep nightfall-worker | awk '{print $1}' || true)
if [ "${WORKER_PROCESS_ID}" ]; then
  docker stop "${WORKER_PROCESS_ID}"
fi
CLIENT_PROCESS_ID=$(docker ps | grep nightfall-client | awk '{print $1}' || true)
if [ "${CLIENT_PROCESS_ID}" ]; then
  docker stop "${CLIENT_PROCESS_ID}"
fi
CLIENT_TXW_PROCESS_ID=$(docker ps | grep nightfall-client_txw | awk '{print $1}' || true)
if [ "${CLIENT_TXW_PROCESS_ID}" ]; then
  docker stop "${CLIENT_TXW_PROCESS_ID}"
fi
CLIENT_BPW_PROCESS_ID=$(docker ps | grep nightfall-client_bpw | awk '{print $1}' || true)
if [ "${CLIENT_BPW_PROCESS_ID}" ]; then
  docker stop "${CLIENT_BPW_PROCESS_ID}"
fi

echo "Init tmux session...."
WORKER_PANE=0
CLIENT_PANE=1
CLIENT_BPW_PANE=2
CLIENT_TXW_PANE=3
init_tmux 

VOLUMES=${PWD}/../volumes/${RELEASE}
mkdir -p ${VOLUMES}/proving_files
# Compare if stored proving files in volumes/ are the same than the ones in EFS. If not, copy them
if [ -f ${VOLUMES}/proving_files/hash.txt ]; then
  DIFF=$(cmp ${VOLUMES}/proving_files/hash.txt ${EFS_MOUNT_POINT}/proving_files/hash.txt || true)
  if [ "${DIFF}" ]; then
     echo "New proving files deployed. Copying them to volume"
     sudo cp -R ${EFS_MOUNT_POINT}/proving_files/* ${VOLUMES}/proving_files/
  else
     echo "Proving files are not modified..."
  fi
else
     echo "New proving files deployed. Copying them to volume"
     sudo cp -R ${EFS_MOUNT_POINT}/proving_files/* ${VOLUMES}/proving_files/
fi

mkdir -p ${VOLUMES}/build
# Compare if stored buildin volumes/ are the same than the ones in EFS. If not, copy them
if [ -f ${VOLUMES}/build/hash.txt ]; then
  DIFF=$(cmp ${VOLUMES}/build/hash.txt ${EFS_MOUNT_POINT}/build/hash.txt || true)
  if [ "${DIFF}" ]; then
     echo "New contracts deployed. Copying them to volume"
     sudo cp -R ${EFS_MOUNT_POINT}/build/* ${VOLUMES}/build/
  else
     echo "Contracts are not modified..."
  fi
else
     echo "New contracts deployed. Copying them to volume"
     sudo cp -R ${EFS_MOUNT_POINT}/build/* ${VOLUMES}/build/
fi

mkdir -p ${VOLUMES}/mongodb

if [ ${DELETE_DB} ]; then
  echo "Deleting existing mongodb..."
  sudo rm -rf ${VOLUMES}/mongodb/*
else
  echo "Keeping existing mongodb..."
fi

echo "Unmount EFS ${EFS_MOUNT_POINT}"
sudo umount -l -f ${EFS_MOUNT_POINT}

echo "Launching mongodb container..."
tmux send-keys -t ${WORKER_PANE} "docker run --rm -d \
   -v ${VOLUMES}/mongodb:/data/db \
   -p 27017:27017 \
   --name mongodb \
   mongo" Enter

echo "Launching worker container..."
tmux send-keys -t ${WORKER_PANE} "docker run --rm -d \
     -v ${VOLUMES}/proving_files:/app/output \
     --name worker -e LOG_LEVEL=${WORKER_LOG_LEVEL} ${ECR_REPO}/nightfall-worker:${RELEASE}" Enter
tmux send-keys -t ${WORKER_PANE} "docker logs -f mongodb &" Enter
tmux send-keys -t ${WORKER_PANE} "docker logs -f worker" Enter


echo "Launching client bp worker..."
while true; do
  WORKER=$(docker inspect worker | grep -m 1 \"IPAddress\" | awk '{print $2}' | tr -d '"|,')
  MONGO_IP=$(docker inspect mongodb | grep -m 1 \"IPAddress\" | awk '{print $2}' | tr -d '"|,')
  if [[ ("${WORKER}") && ("${MONGO_IP}") ]]; then
    echo "Launching client_bpw container Release: ${RELEASE}..."
    tmux send-keys -t ${CLIENT_BPW_PANE} "docker run --rm -d \
         --name client-bpw \
         -v ${VOLUMES}/build:/app/build \
         -p 3020:80 \
         -e MONGO_URL=mongodb://${MONGO_IP}:27017 \
         -e LOG_LEVEL=debug \
         -e LAUNCH_LOCAL=1 \
         -e BLOCKCHAIN_WS_HOST=${BLOCKCHAIN_WS_HOST} \
         -e BLOCKCHAIN_PORT=${BLOCKCHAIN_PORT} \
         -e CIRCOM_WORKER_HOST=${WORKER} \
         -e OPTIMIST_HOST=${OPTIMIST_HTTP_HOST} \
         -e AUTOSTART_RETRIES=${AUTOSTART_RETRIES} \
         -e BLOCKCHAIN_URL=wss://${BLOCKCHAIN_WS_HOST}${BLOCKCHAIN_PATH} \
         -e STATE_GENESIS_BLOCK=${STATE_GENESIS_BLOCK} \
         -e ETH_ADDRESS=${DEPLOYER_ADDRESS} \
         -e GAS_PRICE=${GAS_PRICE} \
         -e GAS=${GAS_USER} \
         -e ENABLE_QUEUE=${ENABLE_QUEUE} \
         -e PERFORMANCE_BENCHMARK_ENABLE=${PERFORMANCE_BENCHMARK_ENABLE} \
         -e CONFIRMATIONS=${BLOCKCHAIN_CONFIRMATIONS} \
         ${ECR_REPO}/nightfall-client_bpw:${RELEASE}" Enter
    tmux send-keys -t ${CLIENT_BPW_PANE} "docker logs -f client-bpw" Enter
    break;
  fi
  sleep 4
done

echo "Launching client tx worker..."
while true; do
  WORKER=$(docker inspect worker | grep -m 1 \"IPAddress\" | awk '{print $2}' | tr -d '"|,')
  MONGO_IP=$(docker inspect mongodb | grep -m 1 \"IPAddress\" | awk '{print $2}' | tr -d '"|,')
  CLIENT_IP=$(docker inspect client | grep -m 1 \"IPAddress\" | awk '{print $2}' | tr -d '"|,')
  if [[ ("${WORKER}") && ("${MONGO_IP}") ]]; then
    echo "Launching client_txw container Release: ${RELEASE}..."
    tmux send-keys -t ${CLIENT_TXW_PANE} "docker run --rm -d \
         --name client-txw \
         -v ${VOLUMES}/build:/app/build \
         -p 3010:80 \
         -e MONGO_URL=mongodb://${MONGO_IP}:27017 \
         -e LOG_LEVEL=debug \
         -e LAUNCH_LOCAL=1 \
         -e BLOCKCHAIN_WS_HOST=${BLOCKCHAIN_WS_HOST} \
         -e BLOCKCHAIN_PORT=${BLOCKCHAIN_PORT} \
         -e CIRCOM_WORKER_HOST=${WORKER} \
         -e OPTIMIST_HOST=${OPTIMIST_HTTP_HOST} \
         -e AUTOSTART_RETRIES=${AUTOSTART_RETRIES} \
         -e BLOCKCHAIN_URL=wss://${BLOCKCHAIN_WS_HOST}${BLOCKCHAIN_PATH} \
         -e STATE_GENESIS_BLOCK=${STATE_GENESIS_BLOCK} \
         -e ETH_ADDRESS=${DEPLOYER_ADDRESS} \
         -e GAS_PRICE=${GAS_PRICE} \
         -e GAS=${GAS_USER} \
         -e ENABLE_QUEUE=${ENABLE_QUEUE} \
         -e CLIENT_TX_WORKER_COUNT=2 \
         -e CLIENT_URL=${CLIENT_IP} \
         -e PERFORMANCE_BENCHMARK_ENABLE=${PERFORMANCE_BENCHMARK_ENABLE} \
         ${ECR_REPO}/nightfall-client_txw:${RELEASE}" Enter
    tmux send-keys -t ${CLIENT_TXW_PANE} "docker logs -f client-txw" Enter
    break;
  fi
  sleep 4
done

echo "Launching client..."
while true; do
  WORKER=$(docker inspect worker | grep -m 1 \"IPAddress\" | awk '{print $2}' | tr -d '"|,')
  MONGO_IP=$(docker inspect mongodb | grep -m 1 \"IPAddress\" | awk '{print $2}' | tr -d '"|,')
  if [[ ("${WORKER}") && ("${MONGO_IP}") ]]; then
    echo "Launching client container Release: ${RELEASE}..."
    tmux send-keys -t ${CLIENT_PANE} "docker run --rm -d \
         --name client \
         -v ${VOLUMES}/build:/app/build \
         -e MONGO_URL=mongodb://${MONGO_IP}:27017 \
         -e LOG_LEVEL=debug \
         -e LAUNCH_LOCAL=1 \
         -e BLOCKCHAIN_WS_HOST=${BLOCKCHAIN_WS_HOST} \
         -e BLOCKCHAIN_PORT=${BLOCKCHAIN_PORT} \
         -e CIRCOM_WORKER_HOST=${WORKER} \
         -e OPTIMIST_HOST=${OPTIMIST_HTTP_HOST} \
         -e AUTOSTART_RETRIES=${AUTOSTART_RETRIES} \
         -e BLOCKCHAIN_URL=wss://${BLOCKCHAIN_WS_HOST}${BLOCKCHAIN_PATH} \
         -e STATE_GENESIS_BLOCK=${STATE_GENESIS_BLOCK} \
         -e ETH_ADDRESS=${DEPLOYER_ADDRESS} \
         -e GAS_PRICE=${GAS_PRICE} \
         -e GAS=${GAS_USER} \
         -e ENABLE_QUEUE=${ENABLE_QUEUE} \
         -e CONFIRMATIONS=${BLOCKCHAIN_CONFIRMATIONS} \
         -e PERFORMANCE_BENCHMARK_ENABLE=${PERFORMANCE_BENCHMARK_ENABLE} \
         ${ECR_REPO}/nightfall-client:${RELEASE}" Enter
    tmux send-keys -t ${CLIENT_PANE} "docker logs -f client" Enter
    break;
  fi
  sleep 4
done

echo "Launch Client"
