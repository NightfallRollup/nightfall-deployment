#! /bin/bash

#  Restart infrastructure services in order
#  - Assumes blockchain is running and the rest of services stopped
#  1) Optimist (opt, opt-txw, opt-pbw and opt-baw)
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

### Set cluster variables
_CLUSTER=${CLUSTER}
if [ "${CLUSTER}" ]; then
  _CLUSTER="${CLUSTER^^}_"
fi

CLUSTER=${CLUSTER} ./create-cluster-envfile.sh
source ../env/cluster.env

set +o allexport

# Check Web3 is running
set +e
#############
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

# Start Optimist TX Workers
if [ "${_OPTIMIST_TX_WORKER_N}" ] && [ "${_OPTIMIST_TX_WORKER_N}" -gt 0 ] && [ "${NIGHTFALL_LEGACY}" != "true" ]; then
  echo "Starting Optimist TX Workers service..."
  OPTIMIST_TXW_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} NEW_DESIRED_COUNT=${_OPTIMIST_TX_WORKER_N} ./status-service.sh opttxw)
  OPTIMIST_TXW_RUNNING=$(echo ${OPTIMIST_TXW_STATUS} | grep Running)
  OPTIMIST_TXW_DESIRED=$(echo ${OPTIMIST_TXW_STATUS} | grep Desired)
  OPTIMIST_TXW_RUNNING_COUNT=$(echo ${OPTIMIST_TXW_RUNNING: -1})
  OPTIMIST_TXW_DESIRED_COUNT=$(echo ${OPTIMIST_TXW_DESIRED: -1})
  
  #if [[  (-z ${OPTIMIST_TXW_STATUS}) || ("${OPTIMIST_TXW_DESIRED_COUNT}" != "0") || ("${OPTIMIST_TXW_RUNNING_COUNT}" != "0") ]]; then
  # echo "Optimist TX Workers Service service is running (and shouldnt). Running tasks : ${OPTIMIST_TXW_RUNNING_COUNT}. Desired tasks: ${OPTIMIST_TXW_DESIRED_COUNT}"
  # echo "Run make-stop opttxw first"
  # exit 1
  #i

  OPTIMIST_TXW_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} NEW_DESIRED_COUNT=${_OPTIMIST_TX_WORKER_N} ./start-service.sh opttxw)
  echo "---- Optimist TX Workers Status ----"
  echo "New ${OPTIMIST_TXW_STATUS}"
fi

# Start Optimist BA Workers
if [ "${_OPTIMIST_N}" ] && [ "${_OPTIMIST_N}" -gt 0 ] && [ "${NIGHTFALL_LEGACY}" != "true" ]; then
  echo "Starting Optimist BA Workers service..."
  OPTIMIST_BAW_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./status-service.sh optbaw)
  OPTIMIST_BAW_RUNNING=$(echo ${OPTIMIST_BAW_STATUS} | grep Running)
  OPTIMIST_BAW_DESIRED=$(echo ${OPTIMIST_BAW_STATUS} | grep Desired)
  OPTIMIST_BAW_RUNNING_COUNT=$(echo ${OPTIMIST_BAW_RUNNING: -1})
  OPTIMIST_BAW_DESIRED_COUNT=$(echo ${OPTIMIST_BAW_DESIRED: -1})
  
  #f [[  (-z ${OPTIMIST_BAW_STATUS}) || ("${OPTIMIST_BAW_DESIRED_COUNT}" != "0") || ("${OPTIMIST_BAW_RUNNING_COUNT}" != "0") ]]; then
  # echo "Optimist BA Workers Service service is running (and shouldnt). Running tasks : ${OPTIMIST_BAW_RUNNING_COUNT}. Desired tasks: ${OPTIMIST_BAW_DESIRED_COUNT}"
  # echo "Run make-stop opttxw first"
  # exit 1
  #i

  OPTIMIST_BAW_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./start-service.sh optbaw)
  echo "---- Optimist BA Workers Status ----"
  echo "New ${OPTIMIST_BAW_STATUS}"
fi

# Start Optimist BP Workers
if [ "${_OPTIMIST_N}" ] && [ "${_OPTIMIST_N}" -gt 0 ] && [ "${NIGHTFALL_LEGACY}" != "true" ]; then
  echo "Starting Optimist BP Workers service..."
  OPTIMIST_BPW_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./status-service.sh optbpw)
  OPTIMIST_BPW_RUNNING=$(echo ${OPTIMIST_BPW_STATUS} | grep Running)
  OPTIMIST_BPW_DESIRED=$(echo ${OPTIMIST_BPW_STATUS} | grep Desired)
  OPTIMIST_BPW_RUNNING_COUNT=$(echo ${OPTIMIST_BPW_RUNNING: -1})
  OPTIMIST_BPW_DESIRED_COUNT=$(echo ${OPTIMIST_BPW_DESIRED: -1})
  
  #f [[  (-z ${OPTIMIST_BPW_STATUS}) || ("${OPTIMIST_BPW_DESIRED_COUNT}" != "0") || ("${OPTIMIST_BPW_RUNNING_COUNT}" != "0") ]]; then
  # echo "Optimist BP Workers Service service is running (and shouldnt). Running tasks : ${OPTIMIST_BPW_RUNNING_COUNT}. Desired tasks: ${OPTIMIST_BPW_DESIRED_COUNT}"
  # echo "Run make-stop opttxw first"
  # exit 1
  #i

  OPTIMIST_BPW_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./start-service.sh optbpw)
  echo "---- Optimist BP Workers Status ----"
  echo "New ${OPTIMIST_BPW_STATUS}"
fi


# Start Optimist
if [ "${_OPTIMIST_N}" ] && [ "${_OPTIMIST_N}" -gt 0 ]; then
  # Check opt txw are alive
  if [ "${_OPTIMIST_TX_WORKER_N}" ] && [ "${_OPTIMIST_TX_WORKER_N}" -gt 0 ] && [ "${NIGHTFALL_LEGACY}" != "true" ]; then
    while true; do
      echo "Waiting for connection with ${_OPTIMIST_TX_WORKER_HOST}..."
      OPTIMIST_TXW_RESPONSE=$(curl https://"${_OPTIMIST_TX_WORKER_HOST}"/healthcheck 2> /dev/null | grep OK || true)
      if [ "${OPTIMIST_TXW_RESPONSE}" ]; then
        echo "Connected to ${_OPTIMIST_TX_WORKER_HOST}..."
	      break
      fi
      sleep 10
    done
  fi

  # Check opt bpw are alive
  if [ "${_OPTIMIST_N}" ] && [ "${_OPTIMIST_N}" -gt 0 ] && [ "${NIGHTFALL_LEGACY}" != "true" ]; then
    while true; do
      echo "Waiting for connection with ${_OPTIMIST_BP_WORKER_HOST}..."
      OPTIMIST_BPW_RESPONSE=$(curl https://"${_OPTIMIST_BP_WORKER_HOST}"/healthcheck 2> /dev/null | grep OK || true)
      if [ "${OPTIMIST_BPW_RESPONSE}" ]; then
        echo "Connected to ${_OPTIMIST_BP_WORKER_HOST}..."
	      break
      fi
      sleep 10
    done
  fi

  # Check opt baw are alive
  if [ "${_OPTIMIST_N}" ] && [ "${_OPTIMIST_N}" -gt 0 ] && [ "${NIGHTFALL_LEGACY}" != "true" ]; then
    while true; do
      echo "Waiting for connection with ${_OPTIMIST_BA_WORKER_HOST}..."
      OPTIMIST_BAW_RESPONSE=$(curl https://"${_OPTIMIST_BA_WORKER_HOST}"/healthcheck 2> /dev/null | grep OK || true)
      if [ "${OPTIMIST_BAW_RESPONSE}" ]; then
        echo "Connected to ${_OPTIMIST_BA_WORKER_HOST}..."
	      break
      fi
      sleep 10
    done
  fi

  echo "Starting Optmist service..."
  OPTIMIST_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./status-service.sh optimist)
  OPTIMIST_RUNNING=$(echo ${OPTIMIST_STATUS} | grep Running)
  OPTIMIST_DESIRED=$(echo ${OPTIMIST_STATUS} | grep Desired)
  OPTIMIST_RUNNING_COUNT=$(echo ${OPTIMIST_RUNNING: -1})
  OPTIMIST_DESIRED_COUNT=$(echo ${OPTIMIST_DESIRED: -1})
  
  #if [[  (-z ${OPTIMIST_STATUS}) || ("${OPTIMIST_DESIRED_COUNT}" != "0") || ("${OPTIMIST_RUNNING_COUNT}" != "0") ]]; then
    #echo "Optimist service is running (and shouldnt). Running tasks : ${OPTIMIST_RUNNING_COUNT}. Desired tasks: ${OPTIMIST_DESIRED_COUNT}"
    #echo "Run make-stop optimist first"
    #exit 1
  #fi
  
  OPTIMIST_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./start-service.sh optimist)
  echo "---- Optimist Status ----"
  echo "New ${OPTIMIST_STATUS}"
  
  # Check optimist/adversary is alive
  while true; do
    echo "Waiting for connection with ${_OPTIMIST_HTTP_HOST}..."
    OPTIMIST_RESPONSE=$(curl https://"${_OPTIMIST_HTTP_HOST}"/contract-address/Shield 2> /dev/null | grep 0x || true)
    if [ "${OPTIMIST_RESPONSE}" ]; then
      echo "Connected to ${_OPTIMIST_HTTP_HOST}..."
	    break
    fi
    sleep 10
  done
fi

# Start challenger
if [ "${_CHALLENGER_N}" ] && [ "${_CHALLENGER_N}" -gt 0 ]; then
  echo "Starting Challenger service..."
  CHALLENGER_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./status-service.sh challenger)
  CHALLENGER_RUNNING=$(echo ${CHALLENGER_STATUS} | grep Running)
  CHALLENGER_DESIRED=$(echo ${CHALLENGER_STATUS} | grep Desired)
  CHALLENGER_RUNNING_COUNT=$(echo ${CHALLENGER_RUNNING: -1})
  CHALLENGER_DESIRED_COUNT=$(echo ${CHALLENGER_DESIRED: -1})
  
  #if [[  (-z ${CHALLENGER_STATUS}) || ("${CHALLENGER_DESIRED_COUNT}" != "0") || ("${CHALLENGER_RUNNING_COUNT}" != "0") ]]; then
    #echo "Challenger service is running (and shouldnt). Running tasks : ${CHALLENGER_RUNNING_COUNT}. Desired tasks: ${CHALLENGER_DESIRED_COUNT}"
    #echo "Run make-stop challenger first"
    #exit 1
  #fi

  CHALLENGER_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./start-service.sh challenger)
  echo "---- Challenger Status ----"
  echo "New ${CHALLENGER_STATUS}"
fi

# Start publisher
if [ "${_PUBLISHER_ENABLE}" ] && [ "${_PUBLISHER_ENABLE}" = "true" ]; then
  echo "Starting Publisher service..."
  PUBLISHER_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./status-service.sh publisher)
  PUBLISHER_RUNNING=$(echo ${PUBLISHER_STATUS} | grep Running)
  PUBLISHER_DESIRED=$(echo ${PUBLISHER_STATUS} | grep Desired)
  PUBLISHER_RUNNING_COUNT=$(echo ${PUBLISHER_RUNNING: -1})
  PUBLISHER_DESIRED_COUNT=$(echo ${PUBLISHER_DESIRED: -1})
  
  #if [[  (-z ${PUBLISHER_STATUS}) || ("${PUBLISHER_DESIRED_COUNT}" != "0") || ("${PUBLISHER_RUNNING_COUNT}" != "0") ]]; then
    #echo "Publisher service is running (and shouldnt). Running tasks : ${PUBLISHER_RUNNING_COUNT}. Desired tasks: ${PUBLISHER_DESIRED_COUNT}"
    #echo "Run make-stop publisher first"
    #exit 1
  #fi

  PUBLISHER_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./start-service.sh publisher)
  echo "---- Publisher Status ----"
  echo "${PUBLISHER_STATUS}"
fi
  

if [ "${_DASHBOARD_ENABLE}" ] && [ "${_DASHBOARD_ENABLE}" = "true" ]; then
  # Start dashboard
  echo "Starting Dashboard service..."
  DASHBOARD_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./status-service.sh dashboard)
  DASHBOARD_RUNNING=$(echo ${DASHBOARD_STATUS} | grep Running)
  DASHBOARD_DESIRED=$(echo ${DASHBOARD_STATUS} | grep Desired)
  DASHBOARD_RUNNING_COUNT=$(echo ${DASHBOARD_RUNNING: -1})
  DASHBOARD_DESIRED_COUNT=$(echo ${DASHBOARD_DESIRED: -1})
  
  #if [[  (-z ${DASHBOARD_STATUS}) || ("${DASHBOARD_DESIRED_COUNT}" != "0") || ("${DASHBOARD_RUNNING_COUNT}" != "0") ]]; then
    #echo "Dashboard service is running (and shouldnt). Running tasks : ${DASHBOARD_RUNNING_COUNT}. Desired tasks: ${DASHBOARD_DESIRED_COUNT}"
    #echo "Run make-stop dashboard first"
    #exit 1
  #fi

  DASHBOARD_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./start-service.sh dashboard)
  echo "---- Dashboard Status ----"
  echo "${DASHBOARD_STATUS}"
fi
  

# Check challenger is alive
if [ "${_CHALLENGER_N}" ] && [ "${_CHALLENGER_N}" -gt 0 ]; then
  while true; do
    echo "Waiting for connection with ${_CHALLENGER_HOST}..."
    CHALLENGER_RESPONSE=$(curl https://"${_CHALLENGER_HOST}"/healthcheck 2> /dev/null | grep OK || true)
    if [ "${CHALLENGER_RESPONSE}" ]; then
      echo "Connected to ${_CHALLENGER_HOST}..."
	    break
    fi
    sleep 10
  done
fi

# Check publisher is alive
if [ "${_PUBLISHER_ENABLE}" ] && [ "${_PUBLISHER_ENABLE}" = "true" ]; then
  while true; do
    echo "Waiting for connection with ${_PUBLISHER_HOST}..."
    PUBLISHER_RESPONSE=$(curl https://"${_PUBLISHER_HOST}"/healthcheck 2> /dev/null | grep OK || true)
    if [ "${PUBLISHER_RESPONSE}" ]; then
      echo "Connected to ${_PUBLISHER_HOST}..."
	    break
    fi
    sleep 10
  done
fi

if [ "${_DASHBOARD_ENABLE}" ] && [ "${_DASHBOARD_ENABLE}" = "true" ]; then
  # Check dashboard is alive
  while true; do
    echo "Waiting for connection with ${_DASHBOARD_HOST}..."
    DASHBOARD_RESPONSE=$(curl https://"${_DASHBOARD_HOST}"/healthcheck 2> /dev/null | grep OK || true)
    if [ "${DASHBOARD_RESPONSE}" ]; then
      echo "Connected to ${_DASHBOARD_HOST}..."
	    break
    fi
    sleep 10
  done
fi

## Client
# Start Worker
echo "Number of clients deployed: ${_CLIENT_N}"
if [[ ("${_CLIENT_N}") && ("${_CLIENT_N}" != "0") ]]; then
  echo "Starting circom worker service..."
  CIRCOM_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} NEW_DESIRED_COUNT=${_CIRCOM_WORKER_N} ./status-service.sh circom)
  CIRCOM_RUNNING=$(echo ${CIRCOM_STATUS} | grep Running)
  CIRCOM_DESIRED=$(echo ${CIRCOM_STATUS} | grep Desired)
  CIRCOM_RUNNING_COUNT=$(echo ${CIRCOM_RUNNING: -1})
  CIRCOM_DESIRED_COUNT=$(echo ${CIRCOM_DESIRED: -1})
  
  #if [[  (-z ${CIRCOM_STATUS}) || ("${CIRCOM_DESIRED_COUNT}" != "0") || ("${CIRCOM_RUNNING_COUNT}" != "0") ]]; then
    #echo "Circom service is running (and shouldnt). Running tasks : ${CIRCOM_RUNNING_COUNT}. Desired tasks: ${CIRCOM_DESIRED_COUNT}"
    #echo "Run make-stop circom first"
    #exit 1
  #fi
  
  CIRCOM_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} NEW_DESIRED_COUNT=${_CIRCOM_WORKER_N} ./start-service.sh circom)
  echo "---- Circom Status ----"
  echo "New ${CIRCOM_STATUS}"
  
  # Check circom worker is alive
  while true; do
    echo "Waiting for connection with ${_CIRCOM_WORKER_HOST}..."
    CIRCOM_RESPONSE=$(curl https://"${_CIRCOM_WORKER_HOST}"/healthcheck 2> /dev/null | grep OK || true)
    if [ "${CIRCOM_RESPONSE}" ]; then
      echo "Connected to ${_CIRCOM_WORKER_HOST}..."
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
  
  #if [[  (-z ${CLIENT_STATUS}) || ("${CLIENT_DESIRED_COUNT}" != "0") || ("${CLIENT_RUNNING_COUNT}" != "0") ]]; then
    #echo "Client service is running (and shouldnt). Running tasks : ${CLIENT_RUNNING_COUNT}. Desired tasks: ${CLIENT_DESIRED_COUNT}"
    #echo "Run make-stop client first"
    #exit 1
  #fi
  
  CLIENT_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./start-service.sh client)
  echo "---- Client Status ----"
  echo "New ${CLIENT_STATUS}"
  

  if [ "${NIGHTFALL_LEGACY}" != "true" ]; then
    # Start Client Auxw Worker
    echo "Starting client AUX service..."
    CLIENT_AUXW_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} NEW_DESIRED_COUNT=${_CLIENT_AUX_WORKER_N} ./status-service.sh clientaux)
    CLIENT_AUXW_RUNNING=$(echo ${CLIENT_AUXW_STATUS} | grep Running)
    CLIENT_AUXW_DESIRED=$(echo ${CLIENT_AUXW_STATUS} | grep Desired)
    CLIENT_AUXW_RUNNING_COUNT=$(echo ${CLIENT_AUXW_RUNNING: -1})
    CLIENT_AUXW_DESIRED_COUNT=$(echo ${CLIENT_AUXW_DESIRED: -1})
  
    CLIENT_AUXW_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} NEW_DESIRED_COUNT=${_CLIENT_AUX_WORKER_N} ./start-service.sh clientaux)
    echo "---- Client aux Status ----"
    echo "New ${CLIENT_AUXW_STATUS}"

    # Start Client BP Worker
    echo "Starting client BP service..."
    CLIENT_BPW_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./status-service.sh clientbpw)
    CLIENT_BPW_RUNNING=$(echo ${CLIENT_BPW_STATUS} | grep Running)
    CLIENT_BPW_DESIRED=$(echo ${CLIENT_BPW_STATUS} | grep Desired)
    CLIENT_BPW_RUNNING_COUNT=$(echo ${CLIENT_BPW_RUNNING: -1})
    CLIENT_BPW_DESIRED_COUNT=$(echo ${CLIENT_BPW_DESIRED: -1})
  
    #if [[  (-z ${CLIENT_BPW_STATUS}) || ("${CLIENT_BPW_DESIRED_COUNT}" != "0") || ("${CLIENT_BPW_RUNNING_COUNT}" != "0") ]]; then
      #echo "Client BP worker service is running (and shouldnt). Running tasks : ${CLIENT_BPW_RUNNING_COUNT}. Desired tasks: ${CLIENT_BPW_DESIRED_COUNT}"
      #echo "Run make-stop client first"
      #exit 1
    #fi
  
    CLIENT_BPW_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./start-service.sh clientbpw)
    echo "---- Client bpw Status ----"
    echo "New ${CLIENT_BPW_STATUS}"

    # Start Client TX Worker
    echo "Starting client TX service..."
    CLIENT_TXW_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} NEW_DESIRED_COUNT=${_CLIENT_TX_WORKER_N} ./status-service.sh clienttxw)
    CLIENT_TXW_RUNNING=$(echo ${CLIENT_TXW_STATUS} | grep Running)
    CLIENT_TXW_DESIRED=$(echo ${CLIENT_TXW_STATUS} | grep Desired)
    CLIENT_TXW_RUNNING_COUNT=$(echo ${CLIENT_TXW_RUNNING: -1})
    CLIENT_TXW_DESIRED_COUNT=$(echo ${CLIENT_TXW_DESIRED: -1})
  
    #if [[  (-z ${CLIENT_TXW_STATUS}) || ("${CLIENT_TXW_DESIRED_COUNT}" != "0") || ("${CLIENT_TXW_RUNNING_COUNT}" != "0") ]]; then
      #echo "Client TX worker service is running (and shouldnt). Running tasks : ${CLIENT_TXW_RUNNING_COUNT}. Desired tasks: ${CLIENT_TXW_DESIRED_COUNT}"
      #echo "Run make-stop client first"
      #exit 1
    #fi
  
    CLIENT_TXW_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} NEW_DESIRED_COUNT=${_CLIENT_TX_WORKER_N} ./start-service.sh clienttxw)
    echo "---- Client txw Status ----"
    echo "New ${CLIENT_TXW_STATUS}"

      # Check client auxw is alive
    while true; do
      echo "Waiting for connection with ${_CLIENT_AUX_WORKER_HOST}..."
      CLIENT_AUXW_RESPONSE=$(curl https://"${_CLIENT_AUX_WORKER_HOST}"/healthcheck 2> /dev/null | grep OK || true)
      if [ "${CLIENT_AUXW_RESPONSE}" ]; then
        echo "Connected to ${_CLIENT_AUX_WORKER_HOST}..."
	      break
      fi
      sleep 10
    done

      # Check client bpw is alive
    while true; do
      echo "Waiting for connection with ${_CLIENT_BP_WORKER_HOST}..."
      CLIENT_BPW_RESPONSE=$(curl https://"${_CLIENT_BP_WORKER_HOST}"/healthcheck 2> /dev/null | grep OK || true)
      if [ "${CLIENT_BPW_RESPONSE}" ]; then
        echo "Connected to ${_CLIENT_BP_WORKER_HOST}..."
	      break
      fi
      sleep 10
    done

    # Check client txis alive
    while true; do
      echo "Waiting for connection with ${_CLIENT_TX_WORKER_HOST}..."
      CLIENT_TXW_RESPONSE=$(curl https://"${_CLIENT_TX_WORKER_HOST}"/healthcheck 2> /dev/null | grep OK || true)
      if [ "${CLIENT_TXW_RESPONSE}" ]; then
        echo "Connected to ${_CLIENT_TX_WORKER_HOST}..."
	      break
      fi
      sleep 10
    done
  fi

    # Check client is alive
  while true; do
    echo "Waiting for connection with ${_CLIENT_HOST}..."
    CLIENT_RESPONSE=$(curl https://"${_CLIENT_HOST}"/healthcheck 2> /dev/null | grep OK || true)
    if [ "${CLIENT_RESPONSE}" ]; then
      echo "Connected to ${_CLIENT_HOST}..."
	    break
    fi
    sleep 10
  done
  
fi

## Regulator
echo "Number of regulators deployed: ${_REGULATOR_N}"
if [[ ("${_REGULATOR_N}") && ("${_REGULATOR_N}" != "0") ]]; then
  # Start Regulator
  echo "Starting Regulator service..."
  REGULATOR_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./status-service.sh regulator)
  REGULATOR_RUNNING=$(echo ${REGULATOR_STATUS} | grep Running)
  REGULATOR_DESIRED=$(echo ${REGULATOR_STATUS} | grep Desired)
  REGULATOR_RUNNING_COUNT=$(echo ${REGULATOR_RUNNING: -1})
  REGULATOR_DESIRED_COUNT=$(echo ${REGULATOR_DESIRED: -1})
  
  REGULATOR_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./start-service.sh regulator)
  echo "---- Regulator Status ----"
  echo "New ${REGULATOR_STATUS}"
  

  if [ "${NIGHTFALL_LEGACY}" != "true" ]; then
    # Start Regulator Auxw Worker
    echo "Starting Regulator AUX service..."
    REGULATOR_AUXW_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} NEW_DESIRED_COUNT=${_REGULATOR_AUX_WORKER_N} ./status-service.sh regaux)
    REGULATOR_AUXW_RUNNING=$(echo ${REGULATOR_AUXW_STATUS} | grep Running)
    REGULATOR_AUXW_DESIRED=$(echo ${REGULATOR_AUXW_STATUS} | grep Desired)
    REGULATOR_AUXW_RUNNING_COUNT=$(echo ${REGULATOR_AUXW_RUNNING: -1})
    REGULATOR_AUXW_DESIRED_COUNT=$(echo ${REGULATOR_AUXW_DESIRED: -1})
  
    REGULATOR_AUXW_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} NEW_DESIRED_COUNT=${_REGULATOR_AUX_WORKER_N} ./start-service.sh regaux)
    echo "---- Regulator aux Status ----"
    echo "New ${REGULATOR_AUXW_STATUS}"

    # Start Regulator BP Worker
    echo "Starting regulator BP service..."
    REGULATOR_BPW_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./status-service.sh regbpw)
    REGULATOR_BPW_RUNNING=$(echo ${REGULATOR_BPW_STATUS} | grep Running)
    REGULATOR_BPW_DESIRED=$(echo ${REGULATOR_BPW_STATUS} | grep Desired)
    REGULATOR_BPW_RUNNING_COUNT=$(echo ${REGULATOR_BPW_RUNNING: -1})
    REGULATOR_BPW_DESIRED_COUNT=$(echo ${REGULATOR_BPW_DESIRED: -1})
  
    REGULATOR_BPW_STATUS=$(AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ./start-service.sh regbpw)
    echo "---- Client bpw Status ----"
    echo "New ${REGULATOR_BPW_STATUS}"

    # Check Regulator auxw is alive
    while true; do
      echo "Waiting for connection with ${_REGULATOR_AUX_WORKER_HOST}..."
      REGULATOR_AUXW_RESPONSE=$(curl https://"${_REGULATOR_AUX_WORKER_HOST}"/healthcheck 2> /dev/null | grep OK || true)
      if [ "${REGULATOR_AUXW_RESPONSE}" ]; then
        echo "Connected to ${_REGULATOR_AUX_WORKER_HOST}..."
	      break
      fi
      sleep 10
    done

    # Check regulator bpw is alive
    while true; do
      echo "Waiting for connection with ${_REGULATOR_BP_WORKER_HOST}..."
      REGULATOR_BPW_RESPONSE=$(curl https://"${_REGULATOR_BP_WORKER_HOST}"/healthcheck 2> /dev/null | grep OK || true)
      if [ "${REGULATOR_BPW_RESPONSE}" ]; then
        echo "Connected to ${_REGULATOR_BP_WORKER_HOST}..."
	      break
      fi
      sleep 10
    done
  fi

  # Check regulator is alive
  while true; do
    echo "Waiting for connection with ${_REGULATOR_HOST}..."
    REGULATOR_RESPONSE=$(curl https://"${_REGULATOR_HOST}"/healthcheck 2> /dev/null | grep OK || true)
    if [ "${REGULATOR_RESPONSE}" ]; then
      echo "Connected to ${_REGULATOR_HOST}..."
	    break
    fi
    sleep 10
  done
  
fi