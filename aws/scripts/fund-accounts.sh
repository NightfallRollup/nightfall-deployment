#! /bin/bash

# Funds accounts

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> COMMAND=<command>./fund-accounts.sh
# 
#  COMMAND can be fund to fund accounts, or empty to check balances

# Export env variables
set -e

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

if [ ! -z "${USE_AWS_PRIVATE_KEY}" ]; then
# Retrieve ETH PRIVATE KEY from AWS
  echo "Retrieving secret /${ENVIRONMENT_NAME}/${DEPLOYER_KEY_PARAM}"
  while true; do
    DEPLOYER_KEY=$(aws ssm get-parameter --name "/${ENVIRONMENT_NAME}/${DEPLOYER_KEY_PARAM}" --with-decryption | jq '.Parameter.Value' | tr -d '"') 
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

if [ -z "${USER_ACCOUNTS}" ]; then
  USER_ACCOUNTS="${USER1_ADDRESS},${USER2_ADDRESS},${BOOT_PROPOSER_ADDRESS},${BOOT_CHALLENGER_ADDRESS},${LIQUIDITY_PROVIDER_ADDRESS}"
fi

# Check ETH and RLN balances
if [ -z "${COMMAND}" ]; then
  if [ "${TOKEN}" = "RLN" ] || [ "${TOKEN}" = "ETH" ]; then
    if [ -z "${ACCOUNT}" ]; then
      echo "Empty Account. Exiting..."
      exit 1
    fi
    if [ "${TOKEN}" = "ETH" ]; then
      cd ../test/colored-money-hardhat && npx hardhat balance --token ${TOKEN} --account ${ACCOUNT} --network ${DEPLOYER_ETH_NETWORK}
    else
      if [ -z "${ENTITY_ID}" ]; then
        echo "Empty Entity Id. Exiting..."
        exit 1
      fi
      cd ../test/colored-money-hardhat && npx hardhat balance --token ${TOKEN} --account ${ACCOUNT} --entityid ${ENTITY_ID} --network ${DEPLOYER_ETH_NETWORK}
    fi
    exit 0
  fi
fi

# Fund ETH and RLN 
if [ "${COMMAND}" = "fund" ]; then
  if [ "${TOKEN}" = "RLN" ] || [ "${TOKEN}" = "ETH" ]; then
    if [ -z "${ACCOUNT}" ]; then
      echo "Empty Account. Exiting..."
      exit 1
    fi
    if [ -z "${AMOUNT}" ]; then
      echo "Empty Amount. Exiting..."
      exit 1
    fi
    if [ "${TOKEN}" = "ETH" ]; then
      cd ../test/colored-money-hardhat && npx hardhat transfer --account ${ACCOUNT} --amount ${AMOUNT} --network ${DEPLOYER_ETH_NETWORK}
    else
      if [ -z "${ENTITY_ID}" ]; then
        echo "Empty Entity Id. Exiting..."
        exit 1
      fi
      cd ../test/colored-money-hardhat && npx hardhat fund --amount ${AMOUNT} --account ${ACCOUNT} --entityid ${ENTITY_ID} ---network ${DEPLOYER_ETH_NETWORK}
    fi
    exit 0
  fi
fi

if [ "$(docker ps | grep client)" ]; then
CLIENT=$(docker inspect client | grep -m 1 \"IPAddress\" | awk '{print $2}' | tr -d '"|,')
fi
if [ "${CLIENT}" ]; then
  CLIENT_URL=http://${CLIENT} 
else
  CLIENT_URL=https://${CLIENT_HOST} 
fi
DEPLOYER_ETH_NETWORK=${DEPLOYER_ETH_NETWORK} USER_ACCOUNTS=${USER_ACCOUNTS} _DEPLOYER_KEY=${DEPLOYER_KEY} CLIENT_URL=${CLIENT_URL} COMMAND=${COMMAND} TOKEN=${TOKEN} node ../nightfall_3/cli/src/fund-accounts.mjs
