#!/usr/bin/env bash
if [ -z "${USE_ROPSTEN_NODE}" ];
then
  # wait until there's a blockchain client up
# while ! nc -z ${BLOCKCHAIN_WS_HOST} ${BLOCKCHAIN_PORT}; do sleep 3; done
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

exec env MONGO_CONNECTION_STRING="mongodb://${MONGO_INITDB_ROOT_USERNAME}:${MONGO_INITDB_ROOT_PASSWORD}@${MONGO_URL}:27017/?replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false" "$@"
