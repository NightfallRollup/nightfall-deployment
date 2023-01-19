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

mkdir -p /tmp
rm -f /tmp/priorities.nightfall
TASK_PRIORITIES=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/priorities" 2> /dev/null | jq '.Parameter.Value' | tr -d '"') 
cd ../aws && TASK_PRIORITIES=${TASK_PRIORITIES} cdk diff

