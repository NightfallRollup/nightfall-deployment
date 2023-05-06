#! /bin/bash

#  Deletes AWS Env file


##  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> ENV_NAME=<xxx>  REGION=<xxx>./destroy-envfile.sh
#   where AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are the AWS credentials
#   ENV_NAME is the environment to be created
#   REGION is the AWS region where environment is to be created

set -e  

if [ -z "${ENV_FILE}" ]; then
  echo "Invalid Env FILE. Exiting..."
  exit 1
fi

# Delete Env file
if [ -f "${ENV_FILE}" ]; then
  echo "Deleting Env File ${ENV_FILE}..."
  rm -f ${ENV_FILE}
fi

GIT_TOKEN_FILE=../aws/git-${ENV_NAME,,}.token

if [ -f "${GIT_TOKEN_FILE}" ]; then
  echo "Deleting Git token file ${GIT_TOKEN_FILE}..."
  rm -f ${GIT_TOKEN_FILE}
fi