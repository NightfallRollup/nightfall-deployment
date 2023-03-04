#! /bin/bash

#  Upgrades docDb instance:

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> INSTANCE_TYPE=<xxxz./upgrade-db.sh
#
#  INSTANCE_TYPE= type of instance
#    Check available type of instances here: https://docs.aws.amazon.com/documentdb/latest/developerguide/db-instance-classes.html
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

if [ -z "${INSTANCE_TYPE}" ]; then
 echo "INSTANCE_TYPE not defined... Exiting"
 exit 1
fi

NEW_INSTANCE=$(aws docdb modify-db-instance \
  --db-instance-identifier ${MONGO_ID} \
  --db-instance-class ${INSTANCE_TYPE} \
  --apply-immediately \
  --region ${REGION} \
  | jq ".DBInstance.PendingModifiedValues.DBInstanceClass" \
  | tr -d '\"')

if [ "${NEW_INSTANCE}" ]; then
  echo "New instance class: ${NEW_INSTANCE}"
else
  echo "Available instance types:"
  aws docdb describe-orderable-db-instance-options \
    --engine docdb \
    --query 'OrderableDBInstanceOptions[*].DBInstanceClass' \
    --region ${REGION}
fi