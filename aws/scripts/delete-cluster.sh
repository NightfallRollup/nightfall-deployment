#! /bin/bash

#  Deploys AWS cluster

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./delete-cluster.sh
#
set -e
# Export env variables
set -o allexport
source ../env/aws.env
if [ ! -f "../env/${RELEASE}.env" ]; then
   echo "Undefined RELEASE ${RELEASE}"
   exit 1
fi
source ../env/${RELEASE}.env
if [[ "${DEPLOYER_ETH_NETWORK}" == "staging"* ]]; then
  SECRETS_ENV=../env/secrets-ganache.env
else
  SECRETS_ENV=../env/secrets.env
fi
source ${SECRETS_ENV}
set +o allexport

if [ -z "${CLUSTER}" ]; then
  echo "Cluster is not defined. Exiting..."
  exit 1
fi

_CLUSTER=${CLUSTER^^}

# Delete previousle added patterns
sed -i "/.*START ${_CLUSTER}_REGULATOR SECTION/, /.*END ${_CLUSTER}_REGULATOR SECTION/d" ../env/${RELEASE}.env
sed -i "/.*START ${_CLUSTER}_CLIENT SECTION/, /.*END ${_CLUSTER}_CLIENT SECTION/d" ../env/${RELEASE}.env

## Add secrets to ssm
aws ssm delete-parameter \
  --name /${ENVIRONMENT_NAME}/${_CLUSTER,,}_${REGULATOR_MNEMONIC_PARAM} \
  --region $REGION > /dev/null || true

aws ssm delete-parameter \
  --name /${ENVIRONMENT_NAME}/${_CLUSTER,,}_${REGULATOR_ZKP_PRIVATE_KEY_PARAM} \
  --region $REGION > /dev/null || true