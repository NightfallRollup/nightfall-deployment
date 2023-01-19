#!/usr/bin/env bash
# wait until a local mongo instance has started
mongod --dbpath /app/admin/mongodb/ --fork --logpath /var/log/mongodb/mongod.log --bind_ip_all
while ! nc -z localhost 27017; do sleep 3; done
echo 'mongodb started'

# wait until there's a blockchain client up
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

exec "$@"
