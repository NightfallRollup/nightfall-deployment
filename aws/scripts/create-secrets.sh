#! /bin/bash

#  Creates some secrets in a specific region

#  Usage
#  ENV_NAME is destination env
#  REGION is destination region
#  SECRET_FILE location of file with secrets

set -e

if [ -z "${ENV_NAME}" ]; then
  echo "ENV_NAME is empty. Exiting..."
  exit 1
fi
if [ -z "${REGION}" ]; then
  echo "REGION is empty. Exiting..."
  exit 1
fi

if [ -z "${SECRET_FILE}" ]; then
  echo "SECRET_FILE empty. Exiting..."
  exit 1
elif [ ! -f "${SECRET_FILE}" ]; then
  echo "${SECRET_FILE} doesnt exit. Exiting..."
  exit 1
fi

while read line; do  
  SECRET_TYPE=$(echo $line | awk '{print $1}')
  SECRET_VALUE=$(echo $line | awk '{print $2}')
  SECRET_NAME=$(echo $line | awk '{print $3}')
  
  echo "Creating Param ${SECRET_NAME} in ${ENV_NAME}..."
  if [ "${SECRET_TYPE}" = "SecureString" ]; then
    aws ssm put-parameter \
      --name /${ENV_NAME}/${SECRET_NAME} \
      --region ${REGION} \
      --type SecureString \
      --value "${SECRET_VALUE}" \
      --overwrite > /dev/null
  elif [ "${SECRET_TYPE}" = "String" ]; then
    aws ssm put-parameter \
      --name /${ENV_NAME}/${SECRET_NAME} \
      --region ${REGION} \
      --type String \
      --value "${SECRET_VALUE}" \
      --overwrite > /dev/null
  elif [ "${SECRET_TYPE}" = "SecureMnemonicString" ]; then
    MNEMONIC=$(echo "${SECRET_VALUE}" | tr _ \ )
    aws ssm put-parameter \
      --name /${ENV_NAME}/${SECRET_NAME} \
      --region ${REGION} \
      --type SecureString \
      --value "${MNEMONIC}" \
      --overwrite > /dev/null
  fi
done < "${SECRET_FILE}"