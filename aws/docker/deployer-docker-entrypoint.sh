#! /bin/bash
set -o errexit
set -o pipefail

while ! nc -z ${BLOCKCHAIN_WS_HOST} 80; do sleep 3; done
while ! nc -z ${CIRCOM_WORKER_HOST} 80; do sleep 3; done

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
