#! /bin/bash

#  Creates new AWS environment

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> ENV_NAME=<xxx>  REGION=<xxx> ./create-env.sh
#   where AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are the AWS credentials
#   ENV_NAME is the environment to be created
#   REGION is the AWS region where environment is to be created
#   
#   Notes:
#   Temporary env should start with tmp-

set -e

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

./create-vpc.sh
./create-cdk-context.sh
./create-efs.sh
SECRET_FILE=../aws/paramstore/params.txt ./create-secrets.sh
./create-db.sh
./create-vpn.sh
./create-apigw.sh
./create-envfile.sh
./create-bucket.sh
./create-reserve.sh