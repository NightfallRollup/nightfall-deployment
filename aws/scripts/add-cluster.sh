#! /bin/bash

#  Deploys AWS cluster

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./add-cluster.sh
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

_CLUSTERS="${_CLUSTER,,},"
# Retrieve clusters 
for tmp in $(cat ../env/${RELEASE}.env | grep "_CLIENT SECTION" | grep START | awk '{split($0,a," "); print a[3]}' | awk '{split($0,a,"_"); print a[1]}' | awk '{ print tolower($0)}'); do
  if [ "${tmp^^}" == "${_CLUSTER}" ]; then
    echo "Cluster ${tmp,,} already added. Exiting..."
    exit 0
  fi
  _CLUSTERS="${_CLUSTERS}${tmp,,},"
done

### Generate regulator mnemonic
REGULATOR_KEYS=$(cd .. && RELEASE=${RELEASE} make mnemonic)
if [ -z "${REGULATOR_KEYS}" ]; then
  echo "Invalid Keys. Exiting...."
  exit 1
fi
REGULATOR_MNEMONIC=$(echo "${REGULATOR_KEYS}" | grep mnemonic: | awk '{split($0,a,": "); print a[2]}')
REGULATOR_PUBLIC_KEY=$(echo "${REGULATOR_KEYS}" | grep Compressed | awk '{split($0,a,": "); print a[2]}')
REGULATOR_PRIVATE_KEY=$(echo "${REGULATOR_KEYS}" | grep Private | awk '{split($0,a,": "); print a[2]}')

echo "Add mnemonic to ssm secrets..."
aws ssm put-parameter \
  --name /${ENVIRONMENT_NAME}/${_CLUSTER,,}_${REGULATOR_MNEMONIC_PARAM} \
  --region ${REGION} \
  --type SecureString \
  --value "${REGULATOR_MNEMONIC}" \
  --overwrite > /dev/null

echo "Add private key to ssm secrets..."
aws ssm put-parameter \
  --name /${ENVIRONMENT_NAME}/${_CLUSTER,,}_${REGULATOR_ZKP_PRIVATE_KEY_PARAM} \
  --region ${REGION} \
  --type SecureString \
  --value "${REGULATOR_PRIVATE_KEY}" \
  --overwrite > /dev/null

# Copy Regulator Section
REGULATOR_SECTION=$(sed -n '/.*START REGULATOR SECTION/, /.*END REGULATOR SECTION/p' ../env/${RELEASE}.env \
  | sed "s/REGULATOR/${_CLUSTER}_REGULATOR/g" \
  | sed "s/regulator/${_CLUSTER,,}-regulator/g" \
  | sed "s/${_CLUSTER,,}-regulator_/${_CLUSTER,,}_regulator_/g" \
  | sed "s/${_CLUSTER_}REGULATOR_ZKP_PUBLIC_KEY=\.*/${_CLUSTER_}REGULATOR_ZKP_PUBLIC_KEY=${REGULATOR_PUBLIC_KEY}/g")

# Copy Client Section
CLIENT_SECTION=$(sed -n '/.*START CLIENT SECTION/, /.*END CLIENT SECTION/p' ../env/${RELEASE}.env \
  | sed "s/CLIENT/${_CLUSTER}_CLIENT/g" \
  | sed "s/CIRCOM/${_CLUSTER}_CIRCOM/g" \
  | sed "s/client/${_CLUSTER,,}-client/g" \
  | sed "s/\${COMMITMENTS_DB}/${_CLUSTER,,}_\${COMMITMENTS_DB}/g" \
  | sed "s/circom/${_CLUSTER,,}-circom/g")

# Delete previously added patterns
sed -i "/.*START ${_CLUSTER}_REGULATOR SECTION/, /.*END ${CLUSTER}_REGULATOR SECTION/d" ../env/${RELEASE}.env
sed -i "/.*START ${_CLUSTER}_CLIENT SECTION/, /.*END ${CLUSTER}_CLIENT SECTION/d" ../env/${RELEASE}.env

# Write Regulator Section
echo "${REGULATOR_SECTION}" >> ../env/${RELEASE}.env

# Write Client Section
echo "${CLIENT_SECTION}" >> ../env/${RELEASE}.env

N_CLUSTERS=$((N_CLUSTERS+1))
perl -i -pe "s#export N_CLUSTERS=.*#export N_CLUSTERS=${N_CLUSTERS}#g" ../env/${RELEASE}.env
perl -i -pe "s#export CURRENT_CLUSTERS=.*#export CURRENT_CLUSTERS=${_CLUSTERS}#g" ../env/${RELEASE}.env
