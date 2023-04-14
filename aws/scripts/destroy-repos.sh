#! /bin/bash

#  Deletes ECR repositories from a given region

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx>  REGION=<xxx>./destroy-repos.sh
#   where AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are the AWS credentials
#   REGION is the AWS region where environment is to be created

if [ -z "${REGION}" ]; then
  echo "Invalid Region. Exiting..."
  exit 1
fi

# Export env variables
set -o allexport
source ../env/init-env.env

repoList=("geth" \
   "nightfall-admin" \
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
   "nightfall-proposer" \
   "nightfall-publisher" \
   "nightfall-worker" \
   "nightfall-lazy_client")

for repo in ${repoList[@]}; do
  echo "Deleting ${repo}..."
  aws ecr delete-repository \
    --region ${REGION} \
    --force \
    --repository-name ${repo} > /dev/null || true
done
