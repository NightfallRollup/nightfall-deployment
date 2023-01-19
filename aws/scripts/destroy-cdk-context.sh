#! /bin/bash

#  Destroys new AWS CDK template

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> ENV_NAME=<xxx>  REGION=<xxx>./destroy-cdk-context.sh
#   where AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are the AWS credentials
#   ENV_NAME is the environment to be created
#   REGION is the AWS region where environment is to be created


if [ -z "${ENV_NAME}" ]; then
  echo "Invalid Env name. Exiting..."
  exit 1
fi
if [ -z "${REGION}" ]; then
  echo "Invalid Region. Exiting..."
  exit 1
fi

# Export env variables
set -o allexport
source ../env/init-env.env

echo -e "\nDeleting CDK template..."
CDK_CONTEXT_FILE="../aws/contexts/cdk.context.${ENV_NAME,,}.json"

if [ ! -f "${CDK_CONTEXT_FILE}" ]; then
  echo "CDK context file ${CDK_CONTEXT_FILE} doesnt exist. Exiting..."
  exit 1
fi
rm -f ${CDK_CONTEXT_FILE}