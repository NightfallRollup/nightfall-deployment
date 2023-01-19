#! /bin/bash

#  Execs into container 

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> COMMAND=>xxxx>./execute-command <task-name>
#    task name can be ganache, mumbai, optimist, proposer, liquidity-provider, challenger or publisher
#    COMMAND is the command to launch  (for example /bin/bash)

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
  echo "Usage: AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> ./execute-command <task-name>"
  exit 1
fi

SELECTED_TASK=$1

declare -a DISCOVERED_TASKS=()
# Get Cluster ARN
CLUSTER_ARN=$(aws ecs list-clusters | jq '.clusterArns[]' | grep ${ENVIRONMENT_NAME} | grep Apps | tr -d '"')
TASKS_ARN=$(aws ecs list-tasks --cluster ${CLUSTER_ARN} | jq '.taskArns[]' | tr -d '"')
for TASK_ARN in ${TASKS_ARN}; do
  TASK_INFO=$(aws ecs describe-tasks --cluster ${CLUSTER_ARN} --tasks ${TASK_ARN})
  TASK_NAME=$(echo "${TASK_INFO}"  | jq '.tasks[0].containers[0].name' | grep "${SELECTED_TASK}" || true)
  DISCOVERED_TASKS+=$(echo "${TASK_INFO} "  | jq '.tasks[0].containers[0].name' | tr -d '"')
  if [ "${TASK_NAME}" ]; then
      TASK_STATUS=$(echo "${TASK_INFO}"  | jq '.tasks[0].lastStatus' | grep RUNNING)
      TASK_ENABLE_EXEC_COMMAND=$(echo "${TASK_INFO}"  | jq '.tasks[0].enableExecuteCommand' | grep true)
      TASK_MANAGED_AGENTS_STATUS=$(echo "${TASK_INFO}"  | jq '.tasks[0].containers[0].managedAgents[0].lastStatus' | grep RUNNING)
      break
  fi
done

# Task not found
if [ -z "${TASK_NAME}" ]; then
  echo "Task ${SELECTED_TASK} not found. Available tasks include ${DISCOVERED_TASKS}"
  exit 1
fi
# Task is not Running
if [ -z "${TASK_STATUS}" ]; then
     TASK_STATUS=$(echo "${TASK_INFO}"  | jq '.tasks[0].lastStatus')
     echo "Task status is not RUNNING. Current status is ${TASK_STATUS}. Try later..."
     exit 1
fi
# Task Exec command not enabled
if [ -z "${TASK_ENABLE_EXEC_COMMAND}" ] || [ -z "${TASK_MANAGED_AGENTS_STATUS}" ]; then
  echo "Exec command is not enabled for selected task. Restart the task and try again"
  exit 1
fi

aws ecs execute-command \
  --cluster ${CLUSTER_ARN}\
  --task ${TASK_ARN} \
  --command "${COMMAND}" \
  --interactive


  


