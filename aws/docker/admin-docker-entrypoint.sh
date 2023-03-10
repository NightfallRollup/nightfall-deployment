#!/usr/bin/env bash
# wait until a local mongo instance has started
mongod --dbpath /app/admin/mongodb/ --fork --logpath /var/log/mongodb/mongod.log --bind_ip_all
while ! nc -z localhost 27017; do sleep 3; done
echo 'mongodb started'

# wait until there's a blockchain client up
while ! nc -z ${BLOCKCHAIN_WS_HOST} 80; do sleep 3; done

exec "$@"
