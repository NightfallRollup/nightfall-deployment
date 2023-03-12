#!/usr/bin/env bash
while ! nc -z ${BLOCKCHAIN_WS_HOST} 80; do sleep 3; done

# wait until there's a circom worker host up
while ! nc -z ${CIRCOM_WORKER_HOST} 80; do sleep 3; done

# wait until there's a rabbitmq server up
if [ "${ENABLE_QUEUE}" == "1" ]
then
  while ! nc -z ${RABBITMQ_HOST:7} $RABBITMQ_PORT; do sleep 3; done
fi

if [ "${LAUNCH_LOCAL}" ]; then
  exec "$@"
else
  exec env MONGO_CONNECTION_STRING="mongodb://${MONGO_INITDB_ROOT_USERNAME}:${MONGO_INITDB_ROOT_PASSWORD}@${MONGO_URL}:27017/?replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false" "$@"
fi
