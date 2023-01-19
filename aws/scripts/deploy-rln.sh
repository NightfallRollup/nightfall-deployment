#! /bin/bash

#  Deploy RLN contracts

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./deploy-rln.sh

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

cp ../test/colored-money-hardhat/.example.env ../test/colored-money-hardhat/.env

DEPLOYER_KEY=$(aws ssm get-parameter --name "/${ENVIRONMENT_NAME}/${DEPLOYER_KEY_PARAM}" --with-decryption | jq '.Parameter.Value' | tr -d '"') 
if [ -z "${DEPLOYER_KEY}" ]; then
  echo "Couldn't read deployer key. Exiting..."
  exit 1
fi

_BLOCKCHAIN_HOST=${BLOCKCHAIN_RPC_HOST}
if [ "${DEPLOYER_ETH_NETWORK}" = "staging_edge" ]; then
  _BLOCKCHAIN_HOST=${BLOCKCHAIN_WS_HOST}
fi

perl -i -pe"s#BLOCKCHAIN_URL.*#BLOCKCHAIN_URL=https://${_BLOCKCHAIN_HOST}#g" ../test/colored-money-hardhat/.env
perl -i -pe"s#PRIVATE_KEY.*#PRIVATE_KEY=${DEPLOYER_KEY}#g" ../test/colored-money-hardhat/.env
perl -i -pe"s#ETH_ADDRESS.*#ETH_ADDRESS=${DEPLOYER_ADDRESS}#g" ../test/colored-money-hardhat/.env

RLN_TOKEN_ADDRESS=$(cd ../test/colored-money-hardhat && npm i > /dev/null && npx hardhat run scripts/deploy_contract.ts --network ${DEPLOYER_ETH_NETWORK} | grep RLN | awk {'print $3'})
echo "RLN Token deployed at ${RLN_TOKEN_ADDRESS}"

# Remove line
perl -ni -we "print unless /.*CONTRACT_ADDRESS/" ../test/colored-money-hardhat/.env
# Add line
echo "CONTRACT_ADDRESS=${RLN_TOKEN_ADDRESS}" >> ../test/colored-money-hardhat/.env