#! /bin/bash

#  Fargate Service status

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./status-service <service-name>
#    service name can be ganache, optimist, proposer, liquidity-provider, challenger,  publisher or dashboard

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
  echo "Usage: AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> ./status-service <service-name>"
  exit 1
fi

SELECTED_SERVICE=$1

declare -a DISCOVERED_TASKS=()
# Get Cluster ARN
CLUSTER_ARN=$(aws ecs list-clusters | jq '.clusterArns[]' | grep ${ENVIRONMENT_NAME} | grep Apps |  tr -d '"')
if [ -z "${CLUSTER_ARN}" ]; then
  echo "Cluster not found"
  exit 1;
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
      # Service status
      echo "Services's Running Count - ${SERVICE_NAME}: ${RUNNING_COUNT}"
      echo "Services's Desired Count - ${SERVICE_NAME}: ${DESIRED_COUNT}"
  fi
done

# Service not found
if [ -z "${SERVICE_FOUND}" ]; then
  echo "Service ${SELECTED_SERVICE} not found. Available tasks include ${DISCOVERED_SERVICES}"
  exit 1
fi


  


