#! /bin/bash

#  ssh to EC2 instance 

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> INSTANCE_NAME=<xxx> ./ssh-ec2.sh
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

if [ -z !${INSTANCE_NAME} ]; then
  echo "Empty instance name. Exiting..."
  exit 1
fi

rm -f ../aws/keys/${ENVIRONMENT_NAME}-${INSTANCE_NAME}-key.pem
mkdir -p ../aws/keys
aws secretsmanager get-secret-value \
  --secret-id ec2-ssh-key/${ENVIRONMENT_NAME}-${INSTANCE_NAME}-key/private \
  --query SecretString  \
  --output text > ../aws/keys/${ENVIRONMENT_NAME}-${INSTANCE_NAME}-key.pem 
chmod 400 ../aws/keys/${ENVIRONMENT_NAME}-${INSTANCE_NAME}-key.pem

instanceIp=$(aws ec2 describe-instances \
 | jq ".Reservations[].Instances[] | select(.Tags[].Value==\"${ENVIRONMENT_NAME}-Apps/EC2Instance-${INSTANCE_NAME}\") | .NetworkInterfaces[].PrivateIpAddress" \
 | tr -d '"')

ssh -i ../aws/keys/${ENVIRONMENT_NAME}-${INSTANCE_NAME}-key.pem ubuntu@${instanceIp}

rm -f ../aws/keys/${ENVIRONMENT_NAME}-${INSTANCE_NAME}-key.pem