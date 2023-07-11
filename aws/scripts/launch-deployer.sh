#! /bin/bash

#  Launches deployer container into the server where this script is executed

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxx> ./launch-deployer.sh
#   where AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are the AWS credentials
#   and RELEASE is the tag for the container image. If not defined, it will be set to latest
#
#  Pre-reqs
#  - Script assumes that a Web3 node in ${BLOCKCHAIN_WS_HOST}:${BLOCKCHAIN_PORT} is running. It will wait 
#   until it can connect to it
set -e  

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
  KILL_SESSION=$(tmux ls 2> /dev/null | grep ${DEPLOYER_SESSION} || true)
  if [ "${KILL_SESSION}" ]; then
     tmux kill-session -t ${DEPLOYER_SESSION}
  fi
  tmux new -d -s ${DEPLOYER_SESSION}
  tmux split-window -h

  init_pane ${DEPLOYER_PANE}
  init_pane ${WORKER_PANE}
}

DEPLOYER_SESSION=${RELEASE}-deployer

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
  
echo "Init tmux session...."
WORKER_PANE=0
DEPLOYER_PANE=1
init_tmux 

# Check efs is mounted
EFS_INFO=$(df -h | grep ${EFS_MOUNT_POINT})
if [ -z "${EFS_INFO}" ]; then
  echo "EFS filesystem ${EFS_MOUNT_POINT} not mounted....exiting"
  exit 1
fi

mkdir -p ${EFS_MOUNT_POINT}/build
mkdir -p ${EFS_MOUNT_POINT}/proving_files
mkdir -p ${EFS_MOUNT_POINT}/.openzeppelin

if [ -z "${UPGRADE}" ]; then
  echo "Deploying contracts..."
  echo "Clearing EFS..."
  if [ -d "${EFS_MOUNT_POINT}" ]; then
    if [ -f "${EFS_MOUNT_POINT}/build/contracts/Shield.json" ]; then
      NET_ID=$(cat ${EFS_MOUNT_POINT}/build/contracts/Shield.json | jq '.networks' | jq 'keys' | tr -d '"\|[\|]\|\n\| ')
    fi
    STORE=${EFS_MOUNT_POINT}/store/"backup-`date +"%d-%m-%Y_%M"`";
    sudo mkdir -p ${EFS_MOUNT_POINT}/store
    sudo mkdir -p ${STORE}
    # If NET_ID is small (testnet), we prompt if contracts and proving files are to be kept. Else (ganache), we delete
    if [[ (( -z "${NET_ID}") || ("${NET_ID}" -lt "6")) && ( -z "${BATCH_DEPLOY}") ]]; then
      while true; do
        read -p "Proceed deleting contents of ${EFS_MOUNT_POINT}/build/ Net ID ${NET_ID} ? [Y/N/B] " PROMPT_BUILD
        case ${PROMPT_BUILD} in
            [Yy]* ) sudo rm -rf ${EFS_MOUNT_POINT}/build/*; break;;
            [Nn]* ) break;;
            [Bb]* ) sudo tar -cvzf ${EFS_MOUNT_POINT}/build.tgz ${EFS_MOUNT_POINT}/build
                    sudo mv ${EFS_MOUNT_POINT}/build.tgz ${STORE}
                    sudo rm -rf ${EFS_MOUNT_POINT}/build/*; break;;
            * ) echo "Please answer Y to delete , N to keep or B to do a backup and delete.";;
        esac
      done
      while true; do
        read -p "Proceed deleting contents of ${EFS_MOUNT_POINT}/proving_files/ Net ID ${NET_ID} ? [Y/N/B] " PROMPT_PROVING_FILES
        case ${PROMPT_PROVING_FILES} in
            [Yy]* ) sudo rm -rf ${EFS_MOUNT_POINT}/proving_files/*; break;;
            [Nn]* ) break;;
            [Bb]* ) sudo tar -cvzf ${EFS_MOUNT_POINT}/proving_files.tgz ${EFS_MOUNT_POINT}/proving_files
                    sudo mv ${EFS_MOUNT_POINT}/proving_files.tgz ${STORE}
                    sudo rm -rf ${EFS_MOUNT_POINT}/proving_files/*; break;;
            * ) echo "Please answer Y to delete , N to keep or B to do a backup and delete.";;
        esac
      done
      while true; do
        read -p "Proceed deleting contents of ${EFS_MOUNT_POINT}/.openzeppelin/ Net ID ${NET_ID} ? [Y/N/B] " PROMPT_OPENZEPPELIN
        case ${PROMPT_OPENZEPPELIN} in
            [Yy]* ) sudo rm -rf ${EFS_MOUNT_POINT}/.openzeppelin/*; break;;
            [Nn]* ) break;;
            [Bb]* ) sudo tar -cvzf ${EFS_MOUNT_POINT}/openzeppelin.tgz ${EFS_MOUNT_POINT}/.openzeppelin
                    sudo mv ${EFS_MOUNT_POINT}/openzeppelin.tgz ${STORE}
                    sudo rm -rf ${EFS_MOUNT_POINT}/.openzeppelin/*; break;;
            * ) echo "Please answer Y to delete , N to keep or B to do a backup and delete.";;
        esac
      done
    else
      sudo rm -rf ${EFS_MOUNT_POINT}/proving_files/*
      sudo rm -rf ${EFS_MOUNT_POINT}/build/*
      sudo rm -rf ${EFS_MOUNT_POINT}/.openzeppelin/*
    fi
  fi
  
  ./create-dynamodb.sh
else
  echo "Upgrading contracts..."
fi

echo "Stopping containers..."
WORKER=$(docker inspect worker 2> /dev/null | grep -m 1 \"IPAddress\" | awk '{print $2}' | tr -d '"|,')
if [ "${WORKER}" ]; then
  docker stop worker;
fi
DEPLOYER=$(docker inspect deployer 2> /dev/null | grep -m 1 \"IPAddress\" | awk '{print $2}' | tr -d '"|,')
if [ "${DEPLOYER}" ]; then
  docker stop deployer;
fi

VOLUMES=$PWD/../volumes/${RELEASE}

echo "Launching worker container..."
if [ -z "${UPGRADE}" ]; then
  sudo rm -rf ${VOLUMES}/proving_files
fi

mkdir -p ${VOLUMES}/proving_files
# Force rapidsnark PROVER_TYPE during deployment
# to build the specific artifacts needed for rapidsnarks.
# This allows to change prover type in a deployed network
tmux send-keys -t ${WORKER_PANE} "docker run --rm -d \
    -v ${VOLUMES}/proving_files:/app/output \
    --name worker -e LOG_LEVEL=${WORKER_LOG_LEVEL} \
    -e PROVER_TYPE=rapidsnark \
    -e CIRCOM_WORKER_COUNT=1 \
    ${ECR_REPO}/nightfall-worker:${RELEASE}" Enter
tmux send-keys -t ${WORKER_PANE} "docker logs -f worker" Enter

if [ ! -z "${USE_AWS_PRIVATE_KEY}" ]; then
# Retrieve ETH PRIVATE KEY from AWS
  echo "Retrieving secret /${ENVIRONMENT_NAME}/${DEPLOYER_KEY_PARAM}"
  while true; do
    DEPLOYER_KEY=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${DEPLOYER_KEY_PARAM}" --with-decryption | jq '.Parameter.Value' | tr -d '"') 
    if [ -z "${DEPLOYER_KEY}" ]; then
     echo "Could not read parameter ${ENVIRONMENT_NAME}/${DEPLOYER_KEY_PARAM}. Retrying..."
     sleep 4
    fi
    break
  done
else
  echo -n "Enter Deployer Private Key "
  read DEPLOYER_KEY
fi

sleep 2
if [ -z "${UPGRADE}" ]; then
  sudo rm -rf ${VOLUMES}/build
  sudo rm -rf ${VOLUMES}/.openzeppelin
fi
mkdir -p ${VOLUMES}/build
mkdir -p ${VOLUMES}/.openzeppelin

echo "Multisig approvers: ${MULTISIG_APPROVERS}"
echo "Multisig signature threshold: ${MULTISIG_SIGNATURE_THRESHOLD}"

while true; do
  WORKER=$(docker inspect worker  2> /dev/null | grep -m 1 \"IPAddress\" | awk '{print $2}' | tr -d '"|,')
  if [ "${WORKER}" ]; then
    echo "Launching deployer container Release: ${RELEASE}..."
    tmux send-keys -t ${DEPLOYER_PANE} "docker run --rm -d \
         -v ${VOLUMES}/build:/app/build \
         -v ${VOLUMES}/.openzeppelin:/app/.openzeppelin \
         --name deployer -e ETH_NETWORK=${DEPLOYER_ETH_NETWORK} \
         -e UPGRADE=${UPGRADE} \
         -e BLOCKCHAIN_WS_HOST=${BLOCKCHAIN_WS_HOST} \
         -e BLOCKCHAIN_PORT=${BLOCKCHAIN_PORT} \
         -e CIRCOM_WORKER_HOST=${WORKER} \
         -e ETH_PRIVATE_KEY=${DEPLOYER_KEY} \
         -e ETH_ADDRESS=${DEPLOYER_ADDRESS} \
         -e USER1_ADDRESS=${USER1_ADDRESS} \
         -e USER2_ADDRESS=${USER2_ADDRESS} \
         -e BOOT_PROPOSER_ADDRESS=${BOOT_PROPOSER_ADDRESS} \
         -e BOOT_CHALLENGER_ADDRESS=${BOOT_CHALLENGER_ADDRESS} \
         -e LIQUIDITY_PROVIDER_ADDRESSS=${LIQUIDITY_PROVIDER_ADDRESS} \
         -e GAS_PRICE=${GAS_PRICE} \
         -e GAS=${GAS_DEPLOYER} \
         -e GAS_ESTIMATE_ENDPOINT=${GAS_ESTIMATE_ENDPOINT} \
         -e PARALLEL_SETUP=${PARALLEL_SETUP} \
         -e ENVIRONMENT=${ENVIRONMENT:?ENVIRONMENT-cannot-be-blank} \
         -e BLOCKCHAIN_URL=wss://${BLOCKCHAIN_WS_HOST}${BLOCKCHAIN_PATH} \
         -e DEPLOY_MOCK_TOKENS=${DEPLOY_MOCK_TOKENS} \
         -e DEPLOY_ERC721_AND_ERC1155_MOCK_TOKENS=${DEPLOY_ERC721_AND_ERC1155_MOCK_TOKENS} \
         -e MULTISIG_SIGNATURE_THRESHOLD=${MULTISIG_SIGNATURE_THRESHOLD} \
         -e MULTISIG_APPROVERS=${MULTISIG_APPROVERS} \
         -e WHITELISTING=${WHITELISTING} \
         -e DEPLOY_MOCKED_SANCTIONS_CONTRACT=${DEPLOY_MOCKED_SANCTIONS_CONTRACT} \
         -e RESTRICT_TOKENS=${RESTRICT_TOKENS} \
         -e WETH_RESTRICT=${WETH_RESTRICT} \
         -e ERC20MOCK_RESTRICT=${ERC20MOCK_RESTRICT} \
         -e MATIC_RESTRICT=${MATIC_RESTRICT} \
         -e USDC_RESTRICT=${USDC_RESTRICT} \
         -e DAI_RESTRICT=${DAI_RESTRICT} \
         ${ECR_REPO}/nightfall-deployer:${RELEASE}" Enter
    tmux send-keys -t ${DEPLOYER_PANE} "docker logs -f deployer" Enter
    break;
  fi
  sleep 4
done

sleep 5
# Wait until deployer is launched
while true; do
   DEPLOYER=$(docker ps | grep ${ECR_REPO}/nightfall-deployer:${RELEASE} || true)
   if [ "${DEPLOYER}" ]; then
      break
   fi
   sleep 5 
done

# Wait until deployer is finished to copy files
while true; do
   DEPLOYER=$(docker ps | grep ${ECR_REPO}/nightfall-deployer:${RELEASE} || true)
   if [ -z "${DEPLOYER}" ]; then
      md5deep -r -s -b ${VOLUMES}/build > hash.txt
      sudo mv hash.txt ${VOLUMES}/build
      md5deep -r -s -b ${VOLUMES}/proving_files > hash.txt
      sudo mv hash.txt ${VOLUMES}/proving_files
      md5deep -r -s -b ${VOLUMES}/.openzeppelin > hash.txt
      sudo mv hash.txt ${VOLUMES}/.openzeppelin
      echo "Copying contracts and proving files to S3 bucket"
      sudo cp -R ${VOLUMES}/proving_files/* ${EFS_MOUNT_POINT}/proving_files/ 
      sudo cp -R ${VOLUMES}/build/* ${EFS_MOUNT_POINT}/build/ 
      sudo cp -R ${VOLUMES}/.openzeppelin/* ${EFS_MOUNT_POINT}/.openzeppelin/ 
      # Delete deployer wallet contents
      aws s3 rm --recursive ${S3_BUCKET_DEPLOYER}
      aws s3 sync ${EFS_MOUNT_POINT}/build ${S3_BUCKET_DEPLOYER}/build 2> /dev/null
      aws s3 sync ${EFS_MOUNT_POINT}/proving_files ${S3_BUCKET_DEPLOYER}/proving_files 2> /dev/null
      aws s3 sync ${EFS_MOUNT_POINT}/.openzeppelin ${S3_BUCKET_DEPLOYER}/.openzeppelin 2> /dev/null
      cd ${EFS_MOUNT_POINT}/proving_files
      # Delete contents
      aws s3 rm --recursive ${S3_BUCKET_WALLET}/circuits
      echo -e "[" > ${VOLUMES}/proving_files/s3_hash.txt

      for PROVING_FILE_FOLDERS in * ; do
        if [ -d "${PROVING_FILE_FOLDERS}" ] && [ "${PROVING_FILE_FOLDERS}" != "prover" ]; then
          aws s3 cp ${PROVING_FILE_FOLDERS}/${PROVING_FILE_FOLDERS}.zkey ${S3_BUCKET_WALLET}/circuits/${PROVING_FILE_FOLDERS}/${PROVING_FILE_FOLDERS}.zkey
          aws s3 cp ${PROVING_FILE_FOLDERS}/${PROVING_FILE_FOLDERS}_js/${PROVING_FILE_FOLDERS}.wasm ${S3_BUCKET_WALLET}/circuits/${PROVING_FILE_FOLDERS}_js/${PROVING_FILE_FOLDERS}.wasm
          HF_ZKEY=$(cat ${VOLUMES}/proving_files/hash.txt | grep ${PROVING_FILE_FOLDERS}.zkey | awk '{print $1}')
          HF_WASM=$(cat ${VOLUMES}/proving_files/hash.txt | grep ${PROVING_FILE_FOLDERS}.wasm | awk '{print $1}')
          CIRCUIT_HASH=$(cat circuithash.txt   \
             | jq ".[] | select(.circuitName == \"${PROVING_FILE_FOLDERS}\") | .circuitHash " \
             | tr -d '\"')
          echo -e "\t{" >> ${VOLUMES}/proving_files/s3_hash.txt
          echo -e "\t\t\"name\": \"${PROVING_FILE_FOLDERS}\","  >> ${VOLUMES}/proving_files/s3_hash.txt
          echo -e "\t\t\"zkh\": \"${HF_ZKEY}\"," >> ${VOLUMES}/proving_files/s3_hash.txt
          echo -e "\t\t\"zk\": \"circuits/${PROVING_FILE_FOLDERS}/${PROVING_FILE_FOLDERS}.zkey\"," >> ${VOLUMES}/proving_files/s3_hash.txt
          echo -e "\t\t\"wasmh\": \"${HF_WASM}\"," >> ${VOLUMES}/proving_files/s3_hash.txt
          echo -e "\t\t\"wasm\": \"circuits/${PROVING_FILE_FOLDERS}_js/${PROVING_FILE_FOLDERS}.wasm\"," >> ${VOLUMES}/proving_files/s3_hash.txt
          echo -e "\t\t\"hash\": \"${CIRCUIT_HASH:0:12}\"" >> ${VOLUMES}/proving_files/s3_hash.txt
          echo -e "\t}," >> ${VOLUMES}/proving_files/s3_hash.txt
        fi
      done
      # Remove last line
      if [ "$(uname)" == "Darwin" ]; then
        # Do something under Mac OS X platform
         sed -i '' -e '$ d' ${VOLUMES}/proving_files/s3_hash.txt
      else
        sed -i '$d' ${VOLUMES}/proving_files/s3_hash.txt
      fi
      echo -e "\t}" >> ${VOLUMES}/proving_files/s3_hash.txt
      echo -e "]" >> ${VOLUMES}/proving_files/s3_hash.txt
      aws s3 cp ${VOLUMES}/proving_files/s3_hash.txt ${S3_BUCKET_WALLET}/s3_hash.txt 2> /dev/null
      break
   fi
   sleep 5 
done


# Stop Worker
echo "Stopping worker docker image..."
if [ "${WORKER}" ]; then
  docker stop worker 2> /dev/null;
fi

# Umount EFS
sleep 5
echo "Umounting EFS unit at ${EFS_MOUNT_POINT}..."
sudo umount -f -l ${EFS_MOUNT_POINT}
rmdir ${EFS_MOUNT_POINT}

# Delete existing mongodb data
echo "Deleting existing local mongoDb data..."
sudo rm -rf ${VOLUMES}/mongodb/*

echo "Deployer launched"
