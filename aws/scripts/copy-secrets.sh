#! /bin/bash

#  Copies secrets from one environment to another

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> SRC_ENV=<xxx> TGT_ENV=<xx> MONGO_PWD=<xxx> ./copy-secrets.sh
#  SRC_ENV is source env
#  TGT_ENV is destination env
#  TGT_REGION is destination region
#  MONGO_PWD is the password to be configured

set -e

if [ ! -f "../env/${SRC_ENV,,}.env" ]; then
   echo "Environment failed ../env/${SRC_ENV}.env} doesnt exit. Exiting..."
   exit 1
fi
# Export env variables
set -o allexport
SECRETS_ENV=../env/secrets-ganache.env
source ${SECRETS_ENV}
source ../env/${SRC_ENV,,}.env
set +o allexport

if [ -z "${SRC_ENV,,}" ]; then
  echo "SRC_ENV is empty. Exiting..."
  exit 1
fi
if [ -z "${TGT_ENV}" ]; then
  echo "TGT_ENV is empty. Exiting..."
  exit 1
fi
if [ -z "${TGT_REGION}" ]; then
  echo "TGT_REGION is empty. Exiting..."
  exit 1
fi
if [ -z "${MONGO_PWD}" ]; then
  echo "MONGO_PWD is empty. Exiting..."
  exit 1
fi
if [ "${#MONGO_PWD}" -lt 8 ]; then
  echo "Password is less than 8 characters. Exiting..."
  exit 1
fi
SRC_REGION=$REGION

#aws ssm put-parameter --name "Carbon" --value "Best Digital Bank Mobile App" --type SecureString --key-id alias/sre-team
SECRETS=$( cat ${SECRETS_ENV} | grep = | awk  '{split($0,a,"="); print a[2]}')
for SECRET in ${SECRETS}; do
  paramValueEnc=$(aws ssm get-parameter \
    --name /${SRC_ENV}/${SECRET} \
    --region $SRC_REGION \
    --with-decryption \
    | jq '.Parameter.Value' \
    | tr -d '"')
  paramValue=$(aws ssm get-parameter \
    --name /${SRC_ENV}/${SECRET} \
    --region $SRC_REGION \
    | jq '.Parameter.Value' \
    | tr -d '"')
  echo "Copying Param ${SECRET} to ${TGT_ENV}..."

  # not encrypted
  putType=SecureString
  if [ "${paramValue}" = "${paramValueEnc}" ]; then
    putType=String
  fi
  aws ssm put-parameter \
    --name /${TGT_ENV}/${SECRET} \
    --region ${TGT_REGION} \
    --type ${putType} \
    --value "${paramValueEnc}" \
    --overwrite > /dev/null
done
echo "Releasing Reserved_Env..."
aws ssm put-parameter \
  --name /${TGT_ENV}/Reserved_Env \
  --region ${TGT_REGION} \
  --type String \
  --value Available \
  --overwrite > /dev/null

echo "Setting mongo_user..."
aws ssm put-parameter \
  --name /${TGT_ENV}/mongo_user \
  --region ${TGT_REGION} \
  --type String \
  --value mongo \
  --overwrite > /dev/null

echo "Setting mongo_password..."
aws ssm put-parameter \
  --name /${TGT_ENV}/mongo_password \
  --region ${TGT_REGION} \
  --type SecureString \
  --value  ${MONGO_PWD} \
  --overwrite > /dev/null