#! /bin/bash
set -o errexit
set -o pipefail

if [ -z "${ETH_PRIVATE_KEY}" ]; then
  while true; do
    echo "Waiting for connection with ${BLOCKCHAIN_WS_HOST}..."
    WEB3_RESPONSE=$(curl -f --write-out '%{http_code}' --silent --output \
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
fi

if [[ "${SKIP_DEPLOYMENT}" != "true" && "${PARALLEL_SETUP}" == "false" ]]; then
  echo "PARALLEL SETUP DISABLED...."
  npx truffle compile --all

  if [ -z "${UPGRADE}" ]; then
    echo "Deploying contracts to ${ETH_NETWORK}"
    npx truffle migrate --to 3 --network=${ETH_NETWORK}
    echo 'Done'
  else
    echo 'Upgrading contracts'
    npx truffle migrate -f 4 --network=${ETH_NETWORK} --skip-dry-run
  fi
fi

npm start
