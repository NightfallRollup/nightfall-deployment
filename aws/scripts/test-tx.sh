#! /bin/bash

#  Launches user to perform transactions

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxx> TX_TYPE=<xxx> ONCHAIN=<xxx> SRC_IDX=<xxx> VALUE=<xxx> L2TX_HASH=<xxx> ERC_NAME=<xxxx> ERC_ADDRESS=<xxxx> ./launch-user.sh
#   where AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are the AWS credentials
#   and RELEASE is the tag for the container image. If not defined, it will be set to latest
#   TX_TYPE=deposit/transfer/withdraw/finalize_withdraw/balance
#   ONCHAIN: if nonempty, transaction (transfer and withdraw) are onchain. If undefined, tx are offchain
#   VALUE: transaction amount in WEI
#   L2TX_HASH: required for finalize_withdraw
#   ERC_NAME : optional name of ERC token
#   ERC_ADDRESS : name of ERC Address. DEfault 0x499d11e0b6eac7c0593d8fb292dcbbf815fb29ae (Matic - Goerli)
#   SRC_IDX: SOurce index address (0|1). DEfault 0
#   TOKEN_ID: token Id. Required for non ERC20 tokens
#   N_TX : Number of transactions

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
## ADD PROPOSER HEADER
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

echo "Launching user 1 with ${TEST_LENGTH} transactions..."
while true; do
  CLIENT=$(docker inspect client | grep -m 1 \"IPAddress\" | awk '{print $2}' | tr -d '"|,')
  if [ "${CLIENT}" ]; then
    USER1_MNEMONIC=${USER1_MNEMONIC} \
    USER1_KEY=${USER1_KEY} \
    USER2_MNEMONIC=${USER2_MNEMONIC} \
    USER2_KEY=${USER2_KEY} \
    CLIENT_HOST=${CLIENT} \
    CLIENT_PORT=80 \
    node ../nightfall_3/cli/src/transaction.mjs
    break;
  fi
  sleep 4
done
  

