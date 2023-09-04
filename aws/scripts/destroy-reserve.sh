#! /bin/bash

#  Destroysreservation secret

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

paramExists=$(aws ssm describe-parameters \
  --region ${REGION} | grep /${ENV_NAME}/Reserved_Env
)
if [ "${paramExists}" ]; then
  echo "Deleting Reservation Param Reserved_Env in ${ENV_NAME}..."
  aws ssm delete-parameter \
    --name /${ENV_NAME}/Reserved_Env \
    --region ${REGION}  > /dev/null
fi