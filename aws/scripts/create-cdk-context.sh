#! /bin/bash

#  Creates new AWS CDK template

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> ENV_NAME=<xxx>  REGION=<xxx>./create-cdk-context.sh
#   where AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are the AWS credentials
#   ENV_NAME is the environment to be created
#   REGION is the AWS region where environment is to be created


if [ -z "${ENV_NAME}" ]; then
  echo "Invalid Env name. Exiting..."
  exit 1
fi
if [ -z "${REGION}" ]; then
  echo "Invalid Region. Exiting..."
  exit 1
fi

# Export env variables
set -o allexport
source ../env/init-env.env
source ../env/aws.env

echo -e "\nCreating CDK template..."
vpcId=$(aws ec2 describe-vpcs \
  --region $REGION \
  | jq ".Vpcs[] | select(.CidrBlock==\"10.48.0.0/16\") | .VpcId" \
  | tr -d '"')

if [ -z "${vpcId}" ]; then
  echo "Couldn't read VPC ID. Exiting..."
  echo 1
fi
# Create cdk template
CDK_CONTEXT_FILE="../aws/contexts/cdk.context.${ENV_NAME,,}.json"
CDK_TEMPLATE_FILE="../aws/contexts/cdk.context.template.json"
cp ${CDK_TEMPLATE_FILE} ${CDK_CONTEXT_FILE}
if [ ! -f "${CDK_CONTEXT_FILE}" ]; then
  echo "Couldnt create CDK Context File ${CDK_CONTEXT_FILE}. Exiting..."
  exit 1
fi
perl -i -pe "s#REGION#${REGION}#g" ${CDK_CONTEXT_FILE}
perl -i -pe "s#ACCOUNT_ID#${ACCOUNT_ID}#g" ${CDK_CONTEXT_FILE}
perl -i -pe "s#VPC_ID#${vpcId}#g" ${CDK_CONTEXT_FILE}

for index in ${!subNetPrivateCidrBlocks[@]}; do
  index1=$(($index+1))
  subnetCidrBlock=${subNetPrivateCidrBlocks[$index]}

  subnetId=$(aws ec2 describe-subnets  \
   --region ${REGION} \
   --filters "Name=vpc-id,Values=${vpcId}" \
   | jq ".Subnets[] | select(.CidrBlock==\"${subnetCidrBlock}\") |  .SubnetId"   | 
   tr -d '"')
  if [ -z ${subnetId} ]; then
    echo "Couldnt find Private Subnet ${subnetId}. Exiting..."
    exit 1
  fi
  perl -i -pe "s#BACK${index1}_SUBNET_ID#${subnetId}#g" ${CDK_CONTEXT_FILE}

  routeTableId=$(aws ec2 describe-route-tables \
    --region ${REGION} \
    --filters "Name=vpc-id,Values=${vpcId}" \
   | jq ".RouteTables[].Associations[] | select(.SubnetId==\"${subnetId}\") |  .RouteTableId"   | 
   tr -d '"')
  perl -i -pe "s#ROUTE_TABLE${index1}_PRIVATE_ID#${routeTableId}#g" ${CDK_CONTEXT_FILE}
done

for index in ${!subNetPublicCidrBlocks[@]}; do
  index1=$(($index+1))
  subnetCidrBlock=${subNetPublicCidrBlocks[$index]}

  subnetId=$(aws ec2 describe-subnets  \
   --region ${REGION} \
   --filters "Name=vpc-id,Values=${vpcId}" \
   | jq ".Subnets[] | select(.CidrBlock==\"${subnetCidrBlock}\") |  .SubnetId"   | 
   tr -d '"')
   perl -i -pe "s#PUBLIC${index1}_SUBNET_ID#${subnetId}#g" ${CDK_CONTEXT_FILE}
done

subnetCidrBlock=${subNetPublicCidrBlocks[0]}
subnetId=$(aws ec2 describe-subnets  \
 --region ${REGION} \
 --filters "Name=vpc-id,Values=${vpcId}" \
 | jq ".Subnets[] | select(.CidrBlock==\"${subnetCidrBlock}\") |  .SubnetId"   | 
 tr -d '"')
routeTableId=$(aws ec2 describe-route-tables \
  --region ${REGION} \
  --filters "Name=vpc-id,Values=${vpcId}" \
 | jq ".RouteTables[].Associations[] | select(.SubnetId==\"${subnetId}\") |  .RouteTableId"   | 
 tr -d '"')
perl -i -pe "s#ROUTE_TABLE_PUBLIC_ID#${routeTableId}#g" ${CDK_CONTEXT_FILE}