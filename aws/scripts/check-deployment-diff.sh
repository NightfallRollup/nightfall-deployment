#! /bin/bash

#  Checks differences between currently deployed infrastrcuture and the one
#   we intend to deploy next

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./check-deployment-diff.sh
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

# Retrieve clusters and capitalize first letter
for tmp in $(cat ../env/${RELEASE}.env | grep "_CLIENT SECTION" | grep START | awk '{split($0,a," "); print a[3]}' | awk '{split($0,a,"_"); print a[1]}' | awk '{ print tolower($0)}'); do
  if [ "${CLUSTERS}" ]; then
    CLUSTERS="${CLUSTERS} ${tmp^}";
  else
    CLUSTERS="${tmp^}";
  fi
done

mkdir -p /tmp
rm -f /tmp/priorities.nightfall
TASK_PRIORITIES=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/priorities" 2> /dev/null | jq '.Parameter.Value' | tr -d '"') 
if [ "${DEPLOYER_EC2}" == "true" ] || [ "${PIPELINE_STACK}" == "true" ]; then
  cd ../aws && TASK_PRIORITIES=${TASK_PRIORITIES} DEPLOYER_EC2=${DEPLOYER_EC2} PIPELINE_STACK=${PIPELINE_STACK} CLUSTERS=${CLUSTERS} cdk diff
else
  cd ../aws && TASK_PRIORITIES=${TASK_PRIORITIES} CLUSTERS=${CLUSTERS} cdk diff
fi

