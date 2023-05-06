#! /bin/bash

#  Destroys deployed AWS infrastructure

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./destroy-cdk.sh
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

TASK_PRIORITIES=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/priorities" 2> /dev/null | jq '.Parameter.Value' | tr -d '"') 
if [ "${DEPLOYER_EC2}" == "true" ]; then
	gh auth login --with-token < ../aws/keys/git-${RELEASE}.token
	GIT_KEY_ID=$(gh ssh-key list | grep deployer-${RELEASE} | awk '{print $5}')
  if [ -z "${GIT_KEY_ID}" ]; then
    echo "git Key not found..."
  else 
	  gh ssh-key delete ${GIT_KEY_ID} -y
  fi
fi
cd ../aws && TASK_PRIORITIES=${TASK_PRIORITIES} cdk destroy --all
# Delete priorities only when not destroying deployer
if [ "${DEPLOYER_EC2}" != "true" ]; then
  aws ssm delete-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/priorities" > /dev/null
fi

