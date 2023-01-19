#! /bin/bash

#  Checks secrets are corrextly configured

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./check-secrets.sh
#
#  Check this: https://faun.pub/deploying-docker-container-with-secrets-using-aws-and-cdk-8ff603092666
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

SECRETS=$( cat ${SECRETS_ENV} | grep = | awk  '{split($0,a,"="); print a[2]}')
for SECRET in ${SECRETS}; do
  if [ -z "$(aws ssm get-parameter --region ${REGION} --name /${ENVIRONMENT_NAME}/${SECRET} | grep Name)" ]; then
     echo "Secret ${SECRET} not found"
     exit 1
  fi
done