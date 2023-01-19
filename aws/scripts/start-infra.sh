#! /bin/bash

#  Restart infrastructure services in order
#  - Assumes blockchain is running and the rest of services stopped
#  1) Optimist
#  2) Proposer
#  3) Challenger
#  4) Publisher
#  5) Dashboard

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./start-infra.sh

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

# Start Optimist
echo "Starting Optmist service..."
OPTIMIST_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./status-service.sh optimist)
OPTIMIST_RUNNING=$(echo ${OPTIMIST_STATUS} | grep Running)
OPTIMIST_DESIRED=$(echo ${OPTIMIST_STATUS} | grep Desired)
OPTIMIST_RUNNING_COUNT=$(echo ${OPTIMIST_RUNNING: -1})
OPTIMIST_DESIRED_COUNT=$(echo ${OPTIMIST_DESIRED: -1})

if [[  (-z ${OPTIMIST_STATUS}) || ("${OPTIMIST_DESIRED_COUNT}" != "0") || ("${OPTIMIST_RUNNING_COUNT}" != "0") ]]; then
  echo "Optimist service is running (and shouldnt). Running tasks : ${OPTIMIST_RUNNING_COUNT}. Desired tasks: ${OPTIMIST_DESIRED_COUNT}"
  echo "Run make-stop optimist first"
  exit 1
fi

OPTIMIST_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./start-service.sh optimist)
echo "---- Optimist Status ----"
echo "New ${OPTIMIST_STATUS}"

# Check optimist/adversary is alive
while true; do
  echo "Waiting for connection with ${OPTIMIST_HTTP_HOST}..."
  OPTIMIST_RESPONSE=$(curl https://"${OPTIMIST_HTTP_HOST}"/contract-address/Shield 2> /dev/null | grep 0x || true)
  if [ "${OPTIMIST_RESPONSE}" ]; then
    echo "Connected to ${OPTIMIST_HTTP_HOST}..."
	  break
  fi
  sleep 10
done

# Start proposer
echo "Starting Proposer service..."
PROPOSER_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./status-service.sh proposer)
PROPOSER_RUNNING=$(echo ${PROPOSER_STATUS} | grep Running)
PROPOSER_DESIRED=$(echo ${PROPOSER_STATUS} | grep Desired)
PROPOSER_RUNNING_COUNT=$(echo ${PROPOSER_RUNNING: -1})
PROPOSER_DESIRED_COUNT=$(echo ${PROPOSER_DESIRED: -1})

if [[  (-z ${PROPOSER_STATUS}) || ("${PROPOSER_DESIRED_COUNT}" != "0") || ("${PROPOSER_RUNNING_COUNT}" != "0") ]]; then
  echo "Proposer services is running (and shouldnt). Running tasks : ${PROPOSER_RUNNING_COUNT}. Desired tasks: ${PROPOSER_DESIRED_COUNT}"
  echo "Run make-stop proposer first"
  exit 1
fi

PROPOSER_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./start-service.sh proposer)
echo "---- Proposer Status ----"
echo "New ${PROPOSER_STATUS}"


# Start challenger
echo "Starting Challenger service..."
CHALLENGER_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./status-service.sh challenger)
CHALLENGER_RUNNING=$(echo ${CHALLENGER_STATUS} | grep Running)
CHALLENGER_DESIRED=$(echo ${CHALLENGER_STATUS} | grep Desired)
CHALLENGER_RUNNING_COUNT=$(echo ${CHALLENGER_RUNNING: -1})
CHALLENGER_DESIRED_COUNT=$(echo ${CHALLENGER_DESIRED: -1})

if [[  (-z ${CHALLENGER_STATUS}) || ("${CHALLENGER_DESIRED_COUNT}" != "0") || ("${CHALLENGER_RUNNING_COUNT}" != "0") ]]; then
  echo "Challenger services is running (and shouldnt). Running tasks : ${CHALLENGER_RUNNING_COUNT}. Desired tasks: ${CHALLENGER_DESIRED_COUNT}"
  echo "Run make-stop challenger first"
  exit 1
fi

CHALLENGER_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./start-service.sh challenger)
echo "---- Challenger Status ----"
echo "New ${CHALLENGER_STATUS}"

# Start publisher
echo "Starting Publisher service..."
PUBLISHER_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./status-service.sh publisher)
PUBLISHER_RUNNING=$(echo ${PUBLISHER_STATUS} | grep Running)
PUBLISHER_DESIRED=$(echo ${PUBLISHER_STATUS} | grep Desired)
PUBLISHER_RUNNING_COUNT=$(echo ${PUBLISHER_RUNNING: -1})
PUBLISHER_DESIRED_COUNT=$(echo ${PUBLISHER_DESIRED: -1})

if [[  (-z ${PUBLISHER_STATUS}) || ("${PUBLISHER_DESIRED_COUNT}" != "0") || ("${PUBLISHER_RUNNING_COUNT}" != "0") ]]; then
  echo "Publisher services is running (and shouldnt). Running tasks : ${PUBLISHER_RUNNING_COUNT}. Desired tasks: ${PUBLISHER_DESIRED_COUNT}"
  echo "Run make-stop publisher first"
  exit 1
fi

PUBLISHER_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./start-service.sh publisher)
echo "---- Publisher Status ----"
echo "${PUBLISHER_STATUS}"


if [ "${DASHBOARD_ENABLE}" = "true" ]; then
  # Start dashboard
  echo "Starting Dashboard service..."
  DASHBOARD_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./status-service.sh dashboard)
  DASHBOARD_RUNNING=$(echo ${DASHBOARD_STATUS} | grep Running)
  DASHBOARD_DESIRED=$(echo ${DASHBOARD_STATUS} | grep Desired)
  DASHBOARD_RUNNING_COUNT=$(echo ${DASHBOARD_RUNNING: -1})
  DASHBOARD_DESIRED_COUNT=$(echo ${DASHBOARD_DESIRED: -1})
  
  if [[  (-z ${DASHBOARD_STATUS}) || ("${DASHBOARD_DESIRED_COUNT}" != "0") || ("${DASHBOARD_RUNNING_COUNT}" != "0") ]]; then
    echo "Dashboard services is running (and shouldnt). Running tasks : ${DASHBOARD_RUNNING_COUNT}. Desired tasks: ${DASHBOARD_DESIRED_COUNT}"
    echo "Run make-stop dashboard first"
    exit 1
  fi

  DASHBOARD_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./start-service.sh dashboard)
  echo "---- Dashboard Status ----"
  echo "${DASHBOARD_STATUS}"
fi
  

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

# Check challenger is alive
while true; do
  echo "Waiting for connection with ${CHALLENGER_HOST}..."
  CHALLENGER_RESPONSE=$(curl https://"${CHALLENGER_HOST}"/healthcheck 2> /dev/null | grep OK || true)
  if [ "${CHALLENGER_RESPONSE}" ]; then
    echo "Connected to ${CHALLENGER_HOST}..."
	  break
  fi
  sleep 10
done


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

if [ "${DASHBOARD_ENABLE}" = "true" ]; then
  # Check dashboard is alive
  while true; do
    echo "Waiting for connection with ${DASHBOARD_HOST}..."
    DASHBOARD_RESPONSE=$(curl https://"${DASHBOARD_HOST}"/healthcheck 2> /dev/null | grep OK || true)
    if [ "${DASHBOARD_RESPONSE}" ]; then
      echo "Connected to ${DASHBOARD_HOST}..."
	    break
    fi
    sleep 10
  done
fi

## Client
# Start Worker
echo "Number of clients deployed: ${CLIENT_N}"
if [[ ("${CLIENT_N}") && ("${CLIENT_N}" != "0") ]]; then
  echo "Starting circom worker service..."
  CIRCOM_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./status-service.sh circom)
  CIRCOM_RUNNING=$(echo ${CIRCOM_STATUS} | grep Running)
  CIRCOM_DESIRED=$(echo ${CIRCOM_STATUS} | grep Desired)
  CIRCOM_RUNNING_COUNT=$(echo ${CIRCOM_RUNNING: -1})
  CIRCOM_DESIRED_COUNT=$(echo ${CIRCOM_DESIRED: -1})
  
  if [[  (-z ${CIRCOM_STATUS}) || ("${CIRCOM_DESIRED_COUNT}" != "0") || ("${CIRCOM_RUNNING_COUNT}" != "0") ]]; then
    echo "Circom service is running (and shouldnt). Running tasks : ${CIRCOM_RUNNING_COUNT}. Desired tasks: ${CIRCOM_DESIRED_COUNT}"
    echo "Run make-stop circom first"
    exit 1
  fi
  
  CIRCOM_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./start-service.sh circom)
  echo "---- Circom Status ----"
  echo "New ${CIRCOM_STATUS}"
  
  # Check circom worker is alive
  while true; do
    echo "Waiting for connection with ${CIRCOM_WORKER_HOST}..."
    CIRCOM_RESPONSE=$(curl https://"${CIRCOM_WORKER_HOST}"/healthcheck 2> /dev/null | grep OK || true)
    if [ "${CIRCOM_RESPONSE}" ]; then
      echo "Connected to ${CIRCOM_WORKER_HOST}..."
	    break
    fi
    sleep 10
  done

  # Start Client
  echo "Starting client service..."
  CLIENT_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./status-service.sh client)
  CLIENT_RUNNING=$(echo ${CLIENT_STATUS} | grep Running)
  CLIENT_DESIRED=$(echo ${CLIENT_STATUS} | grep Desired)
  CLIENT_RUNNING_COUNT=$(echo ${CLIENT_RUNNING: -1})
  CLIENT_DESIRED_COUNT=$(echo ${CLIENT_DESIRED: -1})
  
  if [[  (-z ${CLIENT_STATUS}) || ("${CLIENT_DESIRED_COUNT}" != "0") || ("${CLIENT_RUNNING_COUNT}" != "0") ]]; then
    echo "Client service is running (and shouldnt). Running tasks : ${CLIENT_RUNNING_COUNT}. Desired tasks: ${CLIENT_DESIRED_COUNT}"
    echo "Run make-stop client first"
    exit 1
  fi
  
  CLIENT_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./start-service.sh client)
  echo "---- Circom Status ----"
  echo "New ${CLIENT_STATUS}"
  
  # Check client is alive
  while true; do
    echo "Waiting for connection with ${CLIENT_HOST}..."
    CLIENT_RESPONSE=$(curl https://"${CLIENT_HOST}"/healthcheck 2> /dev/null | grep OK || true)
    if [ "${CLIENT_RESPONSE}" ]; then
      echo "Connected to ${CLIENT_HOST}..."
	    break
    fi
    sleep 10
  done
fi