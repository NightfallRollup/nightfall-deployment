#! /bin/bash

#  Add new RLN entity

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./add-entity-rln.sh

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

cd ../test/colored-money-hardhat && npx hardhat compile
if [ -z "${ACCOUNT}" ] || [ -z "${ENTITY_NAME}" ]; then
  if [ -z "${ACCOUNT}" ]; then
    echo "Empty ACCOUNT. Exiting..."
  else
    echo "Empty Entity name. Exiting..."
  fi

  npx hardhat banks --network ${DEPLOYER_ETH_NETWORK}
  exit 1
fi

npx hardhat bank --account ${ACCOUNT} --name "${ENTITY_NAME}" --network ${DEPLOYER_ETH_NETWORK}