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

# Retrieve clusters 
for tmp in $(cat ../env/${RELEASE}.env | grep "_CLIENT SECTION" | grep START | awk '{split($0,a," "); print a[3]}' | awk '{split($0,a,"_"); print a[1]}' | awk '{ print tolower($0)}'); do
  if [ "${tmp^^}" != "${_CLUSTER}" ]; then
    _CLUSTERS="${_CLUSTERS}${tmp,,},"
  else
    CLUSTER_EXISTS=1
  fi
done

if [ -z "${CLUSTER_EXISTS}" ]; then
  echo "Cluster ${_CLUSTER,,} doesn't exist. Exiting..."
  exit 0
fi

# Delete previously added patterns
sed -i "/.*START ${_CLUSTER}_REGULATOR SECTION/, /.*END ${_CLUSTER}_REGULATOR SECTION/d" ../env/${RELEASE}.env
sed -i "/.*START ${_CLUSTER}_CLIENT SECTION/, /.*END ${_CLUSTER}_CLIENT SECTION/d" ../env/${RELEASE}.env

## Add secrets to ssm
aws ssm delete-parameter \
  --name /${ENVIRONMENT_NAME}/${_CLUSTER,,}_${REGULATOR_MNEMONIC_PARAM} \
  --region $REGION > /dev/null || true

aws ssm delete-parameter \
  --name /${ENVIRONMENT_NAME}/${_CLUSTER,,}_${REGULATOR_ZKP_PRIVATE_KEY_PARAM} \
  --region $REGION > /dev/null || true

N_CLUSTERS=$((N_CLUSTERS-1))
perl -i -pe "s#export N_CLUSTERS=.*#export N_CLUSTERS=${N_CLUSTERS}#g" ../env/${RELEASE}.env
perl -i -pe "s#export CURRENT_CLUSTERS=.*#export CURRENT_CLUSTERS=${_CLUSTERS}#g" ../env/${RELEASE}.env