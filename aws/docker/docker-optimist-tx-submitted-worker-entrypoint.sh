#!/usr/bin/env bash
while ! nc -z ${BLOCKCHAIN_WS_HOST} 80; do sleep 3; done

# Launch Transaction Submitted Workers
exec env MONGO_CONNECTION_STRING="mongodb://${MONGO_INITDB_ROOT_USERNAME}:${MONGO_INITDB_ROOT_PASSWORD}@${MONGO_URL}:27017/?replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false" "$@"
