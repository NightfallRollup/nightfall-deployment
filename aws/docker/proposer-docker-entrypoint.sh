#! /bin/bash
set -o errexit
set -o pipefail
# wait until there's a optimist instance up
echo "Waiting for ${OPTIMIST_HTTP_HOST}..."
while ! nc -z ${OPTIMIST_HTTP_HOST} 80; do sleep 3; done
echo "Waiting for ${OPTIMIST_BA_WORKER_HOST}..."
while ! nc -z ${OPTIMIST_BA_WORKER_HOST} 80; do sleep 3; done
exec "$@"
