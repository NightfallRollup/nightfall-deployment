#! /bin/bash

#  Stops a Fargate Service

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./stop-service <service-name>
#    service name can be ganache, optimist, proposer, liquidity-provider, challenger, publisher or dashboard

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

if  [ "$#" -ne 1 ]; then
  echo "Usage: AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> ./stop-service <service-name>"
  exit 1
fi

SELECTED_SERVICE=$1

declare -a DISCOVERED_TASKS=()
# Get Cluster ARN
CLUSTER_ARN=$(aws ecs list-clusters | jq '.clusterArns[]' | grep ${ENVIRONMENT_NAME} | grep Apps | tr -d '"')
if [ -z "${CLUSTER_ARN}" ]; then
  echo "Cluster not found"
  exit 0;
fi
SERVICE_FOUND=
SERVICES_ARN=$(aws ecs list-services --cluster ${CLUSTER_ARN} | jq '.serviceArns[]' | tr -d '"') 
for SERVICE_ARN in ${SERVICES_ARN}; do
  SERVICE_INFO=$(aws ecs describe-services --cluster ${CLUSTER_ARN} --services ${SERVICE_ARN})
  SERVICE_NAME=$(echo "${SERVICE_INFO}"  | jq '.services[0].serviceName' | grep "${SELECTED_SERVICE}" || true)
  DISCOVERED_SERVICES+=$(echo "${SERVICE_NAME} ")  
  if [ "${SERVICE_NAME}" ]; then
      RUNNING_COUNT=$(echo "${SERVICE_INFO}" | jq '.services[0].runningCount' | tr -d '"')
      DESIRED_COUNT=$(echo "${SERVICE_INFO}" | jq '.services[0].desiredCount' | tr -d '"')
      SERVICE_FOUND=1
      # Service is not Running
      if [ "${DESIRED_COUNT}" = "0" ]; then
         echo "Service ${SERVICE_NAME} has ${RUNNING_COUNT} running tasks and ${DESIRED_COUNT} desired running tasks..."
      else
        # Stop service
        NEW_STATUS=$(aws ecs update-service --cluster ${CLUSTER_ARN} --service ${SERVICE_ARN} --desired-count 0)
        NEW_RUNNING_COUNT=$(echo ${NEW_STATUS} | jq '.service.runningCount' | tr -d '"')
        NEW_DESIRED_COUNT=$(echo ${NEW_STATUS} | jq '.service.desiredCount' | tr -d '"')
        echo "New services's Running Count - ${SERVICE_NAME}: ${NEW_RUNNING_COUNT}"
        echo "New services's Desired Count - ${SERVICE_NAME}: ${NEW_DESIRED_COUNT}"
      fi
  fi
done

# Service not found
if [ -z "${SERVICE_FOUND}" ]; then
  echo "Service ${SELECTED_SERVICE} not found. Available tasks include ${DISCOVERED_SERVICES}"
  exit 0
fi
