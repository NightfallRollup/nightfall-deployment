#! /bin/bash

#  Deletes secrets from one environment

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> ENV_NAME=<xxx> ./destroy-secrets.sh
#   ENV_NAME is the environment to be created
#   REGION is the AWS region where environment is to be created
#   SECRET FILE is the file with the parameters to delete. If file is empty or it doesnt exist, all parameters
#  in region will be deleted

if [ ! -f "../env/${ENV_NAME,,}.env" ]; then
   echo "Environment failed ../env/${ENV_NAME,,}.env doesnt exit. Exiting..."
   exit 1
fi
# Export env variables
set -o allexport
SECRETS_ENV=../env/secrets-ganache.env
source ${SECRETS_ENV}
set +o allexport

if [ -z "${ENV_NAME}" ]; then
  echo "Invalid Env name. Exiting..."
  exit 1
fi
if [ -z "${REGION}" ]; then
  echo "Invalid Region. Exiting..."
  exit 1
fi

SRC_REGION=$REGION

if [[ -z "${SECRET_FILE}" || ! -f "${SECRET_FILE}" ]]; then
  SECRETS=$( cat ${SECRETS_ENV} | grep = | awk  '{split($0,a,"="); print a[2]}')
  for SECRET in ${SECRETS}; do
    echo "Deleting Param ${SECRET} from ${ENV_NAME}..."
    aws ssm delete-parameter \
      --name /${ENV_NAME}/${SECRET} \
      --region $REGION > /dev/null
  done
else
  while read line; do  
    SECRET=$(echo $line | awk '{print $3}')
    echo "Deleting Param ${SECRET} from ${ENV_NAME}..."

    aws ssm delete-parameter \
      --name /${ENV_NAME}/${SECRET} \
      --region ${REGION}  > /dev/null
  done < "${SECRET_FILE}"
fi