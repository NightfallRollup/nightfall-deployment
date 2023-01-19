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

npx truffle compile --all

if [ -z "${UPGRADE}" ]; then
  echo "Deploying contracts: ${ETH_NETWORK}, ${BLOCKCHAIN_URL}, ${ETH_ADDRESS}"
  npx truffle migrate --to 3 --network=${ETH_NETWORK}
else
  echo 'Upgrading contracts'
  npx truffle migrate -f 4 --network=${ETH_NETWORK} --skip-dry-run
fi

#sleep 10

npm start
