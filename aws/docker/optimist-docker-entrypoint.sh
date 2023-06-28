#!/usr/bin/env bash

launchProposer()
{
  while true; do
    echo "Waiting for connection with ${OPTIMIST_HTTP_HOST}..."
    OPTIMIST_RESPONSE=$(curl https://"${OPTIMIST_HTTP_HOST}"/healthcheck 2> /dev/null | grep OK || true)
    if [ "${OPTIMIST_RESPONSE}" ]; then
      echo "Connected to ${OPTIMIST_HTTP_HOST}..."
     break
    fi
    sleep 10
  done

  curl -k -X POST -d "url=https://${OPTIMIST_HTTP_HOST}" https://${OPTIMIST_HTTP_HOST}/proposer/register
}

while ! nc -z ${BLOCKCHAIN_WS_HOST} 80; do sleep 3; done

launchProposer &

exec env MONGO_CONNECTION_STRING="mongodb://${MONGO_INITDB_ROOT_USERNAME}:${MONGO_INITDB_ROOT_PASSWORD}@${MONGO_URL}:27017/?replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false" "$@" 
