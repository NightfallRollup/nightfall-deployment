#! /bin/bash

#  Deletes AWS VPC environment

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> ENV_NAME=<xxx>  REGION=<xxx>./destroy-vpc.sh
#   where AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are the AWS credentials
#   ENV_NAME is the environment to be created
#   REGION is the AWS region where environment is to be created

# set -e  

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

echo -n "Deleting VPC environment..."

vpcId=$(aws ec2 describe-vpcs \
  --region $REGION \
  | jq ".Vpcs[] | select(.CidrBlock==\"${vpcCidrBlock}\") | .VpcId" \
  | tr -d '"')

availableEipallocIds=$(aws ec2 describe-addresses \
  --region $REGION \
  | jq ".Addresses[] | select(.Tags[].Value | startswith(\"${ENV_NAME,,}\")) | .AllocationId" \
  | tr -d '"')

if [ -z "${vpcId}" ]; then
  echo "VPC ${vpcId} doesn't exist"
else
  echo -n "${vpcId}"
  echo ""

  availableNatGwIds=$(aws ec2 describe-nat-gateways \
    --region=${REGION} \
    --filter "Name=vpc-id,Values=${vpcId}" \
    | jq '.NatGateways[] |  select(.State=="available") | .NatGatewayId' \
    | tr -d '"')
  
  for natGatewayId in $availableNatGwIds; do
    echo -n "Deleting NAT GW ${natGatewayId}..."
    aws ec2 delete-nat-gateway \
     --nat-gateway-id ${natGatewayId} \
     --region ${REGION} > /dev/null
    while true; do
      status=$(aws ec2 describe-nat-gateways \
         --region=${REGION} \
         --nat-gateway-id ${natGatewayId} \
        | jq '.NatGateways[] |  select(.State=="deleted")')
      if [ "${status}" ]; then 
        break
      fi
      echo -n "."
      sleep 10
     done
     echo -n "OK"
     echo ""
  done
  availableIgwId=$(aws ec2 describe-internet-gateways \
   --region ${REGION} \
   --filters "Name=attachment.vpc-id,Values=${vpcId}" \
   | jq '.InternetGateways[].InternetGatewayId' \
   | tr -d '"')
  
  if [ "${availableIgwId}" ]; then
    echo "Deleting Internet GW ${availableIgwId}..."
    aws ec2 detach-internet-gateway \
      --internet-gateway-id ${availableIgwId} \
      --region ${REGION} \
      --vpc-id ${vpcId} > /dev/null
    aws ec2 delete-internet-gateway \
      --internet-gateway-id ${availableIgwId} \
      --region ${REGION} > /dev/null
  fi
  
  availableSubnetIds=$(aws ec2 describe-subnets \
    --region ${REGION} \
    --filters "Name=vpc-id,Values=${vpcId}" \
    | jq '.Subnets[].SubnetId' \
    | tr -d '"')
  for subnetId in $availableSubnetIds; do
    echo "Deleting Subnet ${subnetId}..."
    aws ec2 delete-subnet \
      --region ${REGION} \
      --subnet-id ${subnetId} > /dev/null
  done

  ## Get assoc ids
  availableRouteTableAssocIds=$(aws ec2 describe-route-tables \
    --region ${REGION} \
    | jq ".RouteTables[] | select(.VpcId==\"${vpcId}\") | .Associations[].RouteTableAssociationId" \
    | tr -d '\"')

  for routeTableAssocId in $availableRouteTableAssocIds; do
    echo "Disassociating Routing Table with association id ${routeTableAssocId}"...
    aws ec2 disassociate-route-table \
     --region ${REGION} \
     --association-id ${routeTableAssocId}
  done
  availableRouteTableIds=$(aws ec2 describe-route-tables \
    --region ${REGION} \
   --filters "Name=vpc-id,Values=${vpcId}" \
    | jq '.RouteTables[].RouteTableId' \
    | tr -d '"')
  for routeTableId in $availableRouteTableIds; do
    echo "Deleting Routing Table ${routeTableId}..."
    deleteTable=$(aws ec2 describe-route-tables \
      --region ${REGION} \
      --route-table-id ${routeTableId} \
      | jq '.RouteTables[].Tags[].Value' \
      | tr -d '"')
    if [ "${deleteTable}" ]; then
      aws ec2 delete-route-table \
        --region ${REGION} \
        --route-table-id ${routeTableId} > /dev/null
    fi
  done
  
  echo "Deleting VPC ${vpcId}..."
  aws ec2 delete-vpc \
    --vpc-id ${vpcId} \
    --region ${REGION} > /dev/null
fi
  
for eipAllocId in $availableEipallocIds; do
  echo "Deleting Elastic IPs ${eipAllocId}..."
  aws ec2 release-address \
  --allocation-id ${eipAllocId} \
  --region ${REGION} > /dev/null
done