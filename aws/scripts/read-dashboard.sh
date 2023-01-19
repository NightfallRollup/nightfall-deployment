#! /bin/bash

#  Read dashboard

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> COMMAND=<xxx> LIMIT=<xxx>./read-dashboard.sh
# where COMMAND can be alarms to read the alarms, or metrics to read the metrics, flush-alarms or flush-metrics
# and limit is the number of events to display. Default is 1
#
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

MONGO_USERNAME=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${MONGO_INITDB_ROOT_USERNAME_PARAM}" | jq '.Parameter.Value' | tr -d '"') 
MONGO_PASSWORD=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${MONGO_INITDB_ROOT_PASSWORD_PARAM}" --with-decryption | jq '.Parameter.Value' | tr -d '"') 

if [ -z ${LIMIT} ]; then
  LIMIT=1
fi
if [ "${COMMAND}" = "alarms" ] || [ "${COMMAND}" = "flush-alarms" ]; then
  COLLECTION=${ALARMS_COLLECTION}
  LIMIT=1
else 
  COLLECTION=${DASHBOARD_COLLECTION}
fi

if [ "${COMMAND}" = "alarms" ] || [ "${COMMAND}" = "metrics" ]; then
mongosh --host ${MONGO_URL}:27017 \
 --retryWrites=false\
 --username ${MONGO_USERNAME} \
 --password ${MONGO_PASSWORD} \
 --quiet \
 --eval " db.getMongo().use(\"${DASHBOARD_DB}\");\
   db.${COLLECTION}.find({},{_id:0}).sort({_id:-1}).limit(${LIMIT})"
elif [ "${COMMAND}" = "flush-alarms" ] || [ "${COMMAND}" = "flush-metrics" ]; then
mongosh --host ${MONGO_URL}:27017 \
 --retryWrites=false\
 --username ${MONGO_USERNAME} \
 --password ${MONGO_PASSWORD} \
 --quiet \
 --eval " db.getMongo().use(\"${DASHBOARD_DB}\");\
   db.${COLLECTION}.drop()"
else
 echo "Unknown command ${COMMAND}"
fi
    
