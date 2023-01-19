#! /bin/bash

#  Deploy wallet from cloudfront

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./deploy-wallet.sh

# Export env variables
set -o allexport
source ../env/aws.env
if [ ! -f "../env/${RELEASE}.env" ]; then
   echo "Undefined RELEASE ${RELEASE}"
   exit 1
fi
source ../env/${RELEASE}.env
set +o allexport

if [[ -z "${WALLET_HOST}" ]]; then
  echo "WALLET_HOST is not defined. Exiting..."
  exit 1
fi

if [ -z "${S3_BUCKET_CLOUDFRONT}" ]; then
  echo "S3_BUCKET_CLOUDFONT is not defined. Exiting..."
  exit 1
fi

CLOUDFRONT_DISTRIBUTION_ID=$(aws cloudfront list-distributions \
  | jq ".DistributionList.Items[] | select(.Origins.Items[].DomainName ==\"${S3_BUCKET_CLOUDFRONT:5}.s3.${REGION}.amazonaws.com\" or .Origins.Items[].DomainName ==\"${S3_BUCKET_CLOUDFRONT:5}.s3-website.${REGION}.amazonaws.com\") | .Id" \
  | tr -d '\"')

if [ -z "${CLOUDFRONT_DISTRIBUTION_ID}" ]; then
  echo "No Cloudfront distribution id found using ${S3_BUCKET_CLOUDFRONT:5} in region ${REGION}. Exiting..."
  exit 1
fi

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
    echo "Invald Bank Names. Did you created any?"
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

cd ../nightfall_3/wallet && npm i && LOCAL_PROPOSER=false REACT_APP_MODE=${RELEASE} PUBLIC_URL=https://${WALLET_HOST}/ PROPOSER_API_URL=https://${PROPOSER_HOST} PROPOSER_WS_URL=${API_WS_SEND_ENDPOINT} SKIP_PREFLIGHT_CHECK=true DOMAIN_NAME=${DOMAIN_NAME} node scripts/build.js
aws s3 sync build ${S3_BUCKET_CLOUDFRONT} \
 --cache-control max-age=172800 \
 --delete 
aws configure set preview.cloudfront true
aws cloudfront create-invalidation \
  --distribution-id ${CLOUDFRONT_DISTRIBUTION_ID} \
  --region ${REGION} \
  --paths '/*'
