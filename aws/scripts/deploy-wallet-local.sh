#! /bin/bash

#  Deploy wallet from localhost

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./deploy-wallet-local.sh

# Export env variables
set -o allexport
source ../env/aws.env
if [ ! -f "../env/${RELEASE}.env" ]; then
   echo "Undefined RELEASE ${RELEASE}"
   exit 1
fi
source ../env/${RELEASE}.env
set +o allexport

cp ../nightfall_3/wallet/.template.copy.env ../nightfall_3/wallet/.${RELEASE}.env

perl -i -pe"s#PROPOSER_API_URL.*#PROPOSER_API_URL=https://${PROPOSER_HOST}#g" ../nightfall_3/wallet/.${RELEASE}.env
perl -i -pe"s#PROPOSER_WS_URL.*#PROPOSER_WS_URL=${API_WS_SEND_ENDPOINT}#g" ../nightfall_3/wallet/.${RELEASE}.env
# Remove line
perl -ni -we "print unless /.*DOMAIN_NAME/" ../nightfall_3/wallet/.${RELEASE}.env
# add new line
echo "DOMAIN_NAME=${DOMAIN_NAME}" >> ../nightfall_3/wallet/.${RELEASE}.env

newEnv=$(echo "${RELEASE/-/_}")

if [ "${DEPLOYER_ETH_NETWORK}" = "staging" ]; then
  chainId=0x539
  chainName=Ganache
elif [ "${DEPLOYER_ETH_NETWORK}" = "mainnet" ]; then
  chainId=0x1
  chainName=Mainnet
elif [ "${DEPLOYER_ETH_NETWORK}" = "goerli" ]; then
  chainId=0x5
  chainName=Goerli
elif [ "${DEPLOYER_ETH_NETWORK}" = "staging_edge" ]; then
  chainId=0x64
  chainName=Edge
  BANK_NAMES=$(./add-entity-rln.sh | grep "Bank name" |  awk '{split($0,a,","); print a[2]}' | awk '{split($0,a,":"); print a[2]}')
  RLN_CONTRACT_ADDRESS=$(cat ../test/colored-money-hardhat/.env | grep CONTRACT_ADDRESS | awk '{split($0,a,"="); print a[2]}')
  if [ -z "${BANK_NAMES}" ]; then
    echo "Invalid Bank Names. Did you created any?"
  fi
  if [ -z "${RLN_CONTRACT_ADDRESS}" ]; then
    echo "Invald RLN Contract Address. Did you deploy it?"
  fi
  cd ../test/wallet && BANK_NAMES="${BANK_NAMES}" RLN_CONTRACT_ADDRESS=${RLN_CONTRACT_ADDRESS} node edge-tokens.mjs
  cd -
fi

# Remove line
perl -ni -we "print unless /.*${newEnv}/" ../nightfall_3/wallet/src/common-files/utils/web3.js
# add new line
newChainIdMappingEntry="export const ChainIdMapping = {
  ${newEnv}: { chainId: '${chainId}', chainName: '${chainName}' },"
perl -i -pe"s#export const ChainIdMapping.*#${newChainIdMappingEntry}#g" ../nightfall_3/wallet/src/common-files/utils/web3.js

#ERC20Mock=$(curl -s https://${PROPOSER_HOST}/contract-address/ERC20Mock \
 #| jq '.address' | tr -d '\"')

cd ../nightfall_3/wallet && npm i && ENV_NAME=${RELEASE} npm run start:env
