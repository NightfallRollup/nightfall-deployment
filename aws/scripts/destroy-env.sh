#! /bin/bash

#  Deletes AWS environment

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> ENV_NAME=<xxx>  REGION=<xxx>./destroy-env.sh
#   where AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are the AWS credentials
#   and ENV_NAME is the environment to be created
#   REGION is the AWS region where environment is to be created
#


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

./destroy-db.sh
./destroy-efs.sh
./destroy-vpn.sh
./destroy-vpc.sh
./destroy-cdk-context.sh
#./destroy-apigw.sh
./destroy-bucket.sh
SECRET_FILE=../aws/paramstore/params.txt ./destroy-secrets.sh
./destroy-reserve.sh
./destroy-envfile.sh