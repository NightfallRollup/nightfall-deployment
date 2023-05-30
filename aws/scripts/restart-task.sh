#! /bin/bash

#  Restarts a Fargate task

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./restart-task <task-name>
#    task name can be ganache, optimist, proposer, liquidity-provider, challenger, publisher or dashboard

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
  echo "Usage: AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> ./stop-task <task-name>"
  exit 1
fi

if [ -z "${CLUSTER}" ]; then
  CLUSTER=Apps
fi

SELECTED_TASK=$1

declare -a DISCOVERED_TASKS=()
# Get Cluster ARN
CLUSTER_ARN=$(aws ecs list-clusters --region $REGION | jq '.clusterArns[]' | grep ${ENVIRONMENT_NAME} | grep ${CLUSTER} | tr -d '"')
if [ -z "${CLUSTER_ARN}" ]; then
  echo "Cluster not found"
  exit 0;
fi
TASK_FOUND=
TASKS_ARN=$(aws ecs list-tasks --cluster ${CLUSTER_ARN} | jq '.taskArns[]' | tr -d '"')
for TASK_ARN in ${TASKS_ARN}; do
  TASK_INFO=$(aws ecs describe-tasks --cluster ${CLUSTER_ARN} --tasks ${TASK_ARN})
  TASK_NAME=$(echo "${TASK_INFO}"  | jq '.tasks[0].containers[0].name' | grep "${SELECTED_TASK}" || true)
  DISCOVERED_TASKS+=$(echo "${TASK_INFO} "  | jq '.tasks[0].containers[0].name' | tr -d '"')
  if [ "${TASK_NAME}" ]; then
      TASK_STATUS=$(echo "${TASK_INFO}"  | jq '.tasks[0].lastStatus' | grep RUNNING)
      TASK_FOUND=1
      # Task is not Running
      if [ -z "${TASK_STATUS}" ]; then
        TASK_STATUS=$(echo "${TASK_INFO}"  | jq '.tasks[0].lastStatus')
        echo "Task ${TASK_NAME} status is not RUNNING. Current status is ${TASK_STATUS}. Try later..."
      else
        # Stop task
        TASK_NEW_STATUS=$(aws ecs stop-task --cluster ${CLUSTER_ARN} --task ${TASK_ARN} | jq '.task.desiredStatus' | tr -d '"')
        echo "New task's status - ${TASK_NAME}: $TASK_NEW_STATUS"
      fi
  fi
done

# Task not found
if [ -z "${TASK_FOUND}" ]; then
  echo "Task ${SELECTED_TASK} not found. Available tasks include ${DISCOVERED_TASKS}"
  exit 0
fi

