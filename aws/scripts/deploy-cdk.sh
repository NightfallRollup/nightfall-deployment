#! /bin/bash

#  Deploys AWS infrastructure

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./deploy-cdk.sh
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

if [ -z "${STACK}" ]; then
  STACK=--all
fi

# Retrieve clusters and capitalize first letter
for tmp in $(cat ../env/${RELEASE}.env | grep "_CLIENT SECTION" | grep START | awk '{split($0,a," "); print a[3]}' | awk '{split($0,a,"_"); print a[1]}' | awk '{ print tolower($0)}'); do
  if [ "${CLUSTERS}" ]; then
    CLUSTERS="${CLUSTERS} ${tmp^}";
  else
    CLUSTERS="${tmp^}";
  fi
done
  
# Retrieve existing task priorities from ssm
mkdir -p /tmp
rm -f /tmp/nightfall.priority
TASK_PRIORITIES=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/priorities" 2> /dev/null | jq '.Parameter.Value' | tr -d '"') 
cd ../aws && SAVE_TASK_PRIORITY=1 TASK_PRIORITIES=${TASK_PRIORITIES} CLUSTERS=${CLUSTERS} cdk deploy ${STACK}  --require-approval never
TASK_PRIORITIES=$(cat /tmp/nightfall.priority)
aws ssm put-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/priorities" --type "String" --value "${TASK_PRIORITIES}" --overwrite > /dev/null
rm -rf /tmp/nightfall.priority

