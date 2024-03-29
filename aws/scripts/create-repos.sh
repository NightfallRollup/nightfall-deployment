#! /bin/bash

#  Creates new ECR repos

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx>  REGION=<xxx>./create-repos.sh
#   where AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are the AWS credentials
#   ENV_NAME is the environment to be created
#   REGION is the AWS region where environment is to be created

if [ -z "${REGION}" ]; then
  echo "Invalid Region. Exiting..."
  exit 1
fi

# Export env variables
set -o allexport
source ../env/init-env.env

repoList=("nightfall-admin" \
   "nightfall-adversary" \
   "nightfall-dashboard" \
   "nightfall-challenger" \
   "nightfall-client" \
   "nightfall-client_txw" \
   "nightfall-client_bpw" \
   "nightfall-client_auxw" \
   "nightfall-deployer" \
   "nightfall-optimist" \
   "nightfall-opt_txw" \
   "nightfall-opt_bpw" \
   "nightfall-opt_baw" \
   "nightfall-publisher" \
   "nightfall-worker" \
   "nightfall-lazy_client")


echo "Creating repos in ${REGION}..."
for repo in ${repoList[@]}; do
  repoExists=$(aws ecr describe-repositories \
     --region ${REGION} \
     | jq '.repositories[].repositoryUri' | grep ${repo})
  if [ -z "${repoExists}" ]; then
    echo "Creating repo ${repo}..."
    aws ecr create-repository \
      --region ${REGION} \
      --repository-name ${repo} > /dev/null
  fi
done