#! /bin/bash

#  Creates reservation secret

#  Usage
#  ENV_NAME is destination env
#  REGION is destination region

set -e

if [ -z "${ENV_NAME}" ]; then
  echo "ENV_NAME is empty. Exiting..."
  exit 1
fi
if [ -z "${REGION}" ]; then
  echo "REGION is empty. Exiting..."
  exit 1
fi

echo "Creating Reservation Param Reserved_Env in ${ENV_NAME}..."
aws ssm put-parameter \
  --name /${ENV_NAME}/Reserved_Env \
  --value Available \
  --region ${REGION} \
  --type String \
  --overwrite > /dev/null