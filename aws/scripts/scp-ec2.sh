#! /bin/bash

#  scp to EC2 instance 

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> INSTANCE_NAME=<xxx> SRC_FILE=<xxx> DST_FILE=<xxx> ./scp-ec2.sh
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

if [ -z "${SRC_FILE}" ]; then
  echo "Empty Source file. Exiting..."
  exit 1
fi

if [ -z "${DST_FILE}" ]; then
  echo "Empty Destination file. Exiting..."
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
 | jq ".Reservations[].Instances[] | select(.Tags[].Value==\"${ENVIRONMENT_NAME}-${CDK_STACK}/EC2Instance-${INSTANCE_NAME}\") | .NetworkInterfaces[].PrivateIpAddress" \
 | tr -d '"')

if [ -z "${TGT_EC2}" ]; then
  scp -i ../aws/keys/${ENVIRONMENT_NAME}-${INSTANCE_NAME}-key.pem ${SRC_FILE} ubuntu@${instanceIp}:/${DST_FILE}
else
  scp -i ../aws/keys/${ENVIRONMENT_NAME}-${INSTANCE_NAME}-key.pem ubuntu@${instanceIp}:/${SRC_FILE} ${DST_FILE}
fi  

rm -f ../aws/keys/${ENVIRONMENT_NAME}-${INSTANCE_NAME}-key.pem