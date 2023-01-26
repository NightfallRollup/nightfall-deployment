#! /bin/bash

#  Creates new AWS VPC

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxx> ./create-vpc.sh
#   where AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are the AWS credentials
#   and RELEASE is the tag for the container image. If not defined, it will be set to latest


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

subNetPublicIds=()
subNetPrivateIds=()
routeTablePrivateIds=()
natGatewayIds=()

echo "Creating VPC environment..."
echo ""

vpcExists=$(aws ec2 describe-vpcs \
  --region $REGION \
  | jq ".Vpcs[] | select(.CidrBlock==\"${vpcCidrBlock}\") | .Tags[].Value" \
  | grep ${ENV_NAME})

if [ ! -z "${vpcExists}" ]; then
  echo "VPC ${vpcName} for ${ENV_NAME} already exists. Exiting..."
  exit 1
fi

#create vpc with cidr block /16
echo -n "Creating VPC ${vpcName}..."
aws_response=$(aws ec2 create-vpc \
 --cidr-block "$vpcCidrBlock" \
 --region "$REGION" \
 --output json)
vpcId=$(echo -e "$aws_response" |  /usr/bin/jq '.Vpc.VpcId' | tr -d '"')
if [ -z "${vpcId}" ]; then
  echo "VPC couldnt be created. Exiting..."
  exit 1
fi
echo -n "${vpcId}"
echo ""

#name the vpc
aws ec2 create-tags \
  --resources "$vpcId" \
  --tags Key=Name,Value="$vpcName" \
  --region=$REGION > /dev/null
#add dns support
echo "Enabling DNS..."
modify_response=$(aws ec2 modify-vpc-attribute \
 --vpc-id "$vpcId" \
 --enable-dns-support "{\"Value\":true}" \
 --region=$REGION)
#add dns hostnames
echo "Adding DNS hostnames..."
modify_response=$(aws ec2 modify-vpc-attribute \
  --vpc-id "$vpcId" \
  --enable-dns-hostnames "{\"Value\":true}" \
  --region=${REGION})

#create internet gateway
echo -n "Creating IGW ${gatewayName}..."
gateway_response=$(aws ec2 create-internet-gateway \
 --output json \
 --region=${REGION})
gatewayId=$(echo -e "$gateway_response" |  /usr/bin/jq '.InternetGateway.InternetGatewayId' | tr -d '"')
if [ -z "${gatewayId}" ]; then
  echo "IGW ${gatewayName} couldnt be created. Exiting..."
  exit 1
fi
echo -n "${gatewayId}"
echo ""

#name the internet gateway
aws ec2 create-tags \
  --resources "$gatewayId" \
  --tags Key=Name,Value="$gatewayName" \
  --region=$REGION > /dev/null

#attach gateway to vpc
echo "Attaching IGW to VPC..."
attach_response=$(aws ec2 attach-internet-gateway \
 --internet-gateway-id "$gatewayId"  \
 --region=$REGION \
 --vpc-id "$vpcId")


#create route table for vpc
echo "Creating Public Route Table ${routeTablePublicName}..."
route_table_response=$(aws ec2 create-route-table \
 --vpc-id "$vpcId" \
 --region=$REGION \
 --output json)
routeTablePublicId=$(echo -e "$route_table_response" |  /usr/bin/jq '.RouteTable.RouteTableId' | tr -d '"')
#name the route table
if [ -z "${routeTablePublicId}" ]; then
  echo "Couldnt create Public Route Table ${routeTablePublicName}. Exiting..."
  exit 1
fi
aws ec2 create-tags \
  --resources "$routeTablePublicId" \
  --region=$REGION \
  --tags Key=Name,Value="$routeTablePublicName" > /dev/null

#add route for the internet gateway
echo "Adding IGW route to ${routeTablePublicName}..."
route_response=$(aws ec2 create-route \
 --route-table-id "$routeTablePublicId" \
 --destination-cidr-block "$destinationCidrBlock" \
 --region=$REGION \
 --gateway-id "$gatewayId")


#create public subnet for vpc with /24 cidr block
for index in ${!availabilityZones[@]}; do
  availabilityZone=${availabilityZones[$index]}
  subNetPublicCidrBlock=${subNetPublicCidrBlocks[$index]} 
  subNetPublicName=${subNetPublicNames[$index]}
  subNetNatName=${subNetNatNames[$index]}
  echo -n "Creating Public Subnet ${subNetPublicName}..."

  subnet_response=$(aws ec2 create-subnet \
   --cidr-block "$subNetPublicCidrBlock" \
   --availability-zone "$availabilityZone" \
   --vpc-id "$vpcId" \
   --region=$REGION \
   --output json)
  subnetId=$(echo -e "$subnet_response" |  /usr/bin/jq '.Subnet.SubnetId' | tr -d '"')
  if [ -z "${subnetId}" ]; then
    echo "Couldnt create Public Subnet ${subNetPublicName}. Exiting..."
    exit 1
  fi
  echo -n "${subnetId}"
  echo ""
  subNetPublicIds+=($subnetId)
  #name the subnet
  aws ec2 create-tags \
    --resources "$subnetId" \
    --region=$REGION \
    --tags Key=Name,Value="$subNetPublicName" > /dev/null
  echo "Enabling public Ip on Public Subnet ${subNetPublicName}..."
  #enable public ip on subnet
  modify_response=$(aws ec2 modify-subnet-attribute \
   --subnet-id "$subnetId" \
   --region=$REGION \
   --map-public-ip-on-launch)
  #add route to subnet
  echo "Adding route to Public Subnet ${subNetPublicName}..."
  associate_response=$(aws ec2 associate-route-table \
    --subnet-id "$subnetId" \
    --region=$REGION \
    --route-table-id "$routeTablePublicId")
  #Allocate elastic IP
  echo "Allocating Public IP to Public Subnet ${subNetPublicName}..."
  eip_response=$(aws ec2 allocate-address \
   --domain=vpc \
   --region=$REGION)
  allocation_id=$(echo -e "$eip_response" |  /usr/bin/jq '.AllocationId' | tr -d '"')
  if [ -z "${allocation_id}" ]; then
    echo "Couldnt allocate public Ip to ${subNetPublicName}. Exiting..."
    exit 1
  fi
  aws ec2 create-tags \
    --resources "$allocation_id" \
    --region=$REGION \
    --tags Key=Name,Value="${ENV_NAME,,}-eip-$index" > /dev/null
  #create NAT
  echo -n "Creating NAT on Public Subnet ${subNetPublicName}..."
  nat_response=$(aws ec2 create-nat-gateway \
    --region=$REGION \
    --allocation-id=$allocation_id \
    --subnet-id "$subnetId") 
  natGatewayId=$(echo -e "$nat_response" |  /usr/bin/jq '.NatGateway.NatGatewayId' | tr -d '"')
  if [ -z "${natGatewayId}" ]; then
    echo "Couldnt create NAT on Public Subnet ${subNetPublicName}. Exiting..."
    exit 1
  fi
  natGatewayIds+=($natGatewayId)
  #name the NAT
  aws ec2 create-tags \
    --resources "$natGatewayId" \
    --region=$REGION \
    --tags Key=Name,Value="$subNetNatName" > /dev/null

  while true; do 
    status=$(aws ec2 describe-nat-gateways \
      --region $REGION \
      --filter "Name=subnet-id,Values=${subnetId}" \
      | jq '.NatGateways[] |  select(.State=="available") | .NatGatewayId' \
      | tr -d '"')
      if [ "${status}" ]; then
        break
      fi
      echo -n "."
      sleep 5
  done
  echo -n "${natGatewayId}"
  echo ""
done

#create private subnet for vpc with /24 cidr block
for index in ${!availabilityZones[@]}; do
  availabilityZone=${availabilityZones[$index]}
  subNetPrivateCidrBlock=${subNetPrivateCidrBlocks[$index]} 
  subNetPrivateName=${subNetPrivateNames[$index]}
  routeTablePrivateName=${routeTablePrivateNames[$index]}
  natGatewayId=${natGatewayIds[$index]}

  echo "Creating Private Subnet ${subNetPrivateName}..."
  subnet_response=$(aws ec2 create-subnet \
   --cidr-block "$subNetPrivateCidrBlock" \
   --availability-zone "$availabilityZone" \
   --region=$REGION \
   --vpc-id "$vpcId" \
   --output json)
  subnetId=$(echo -e "$subnet_response" |  /usr/bin/jq '.Subnet.SubnetId' | tr -d '"')
  if [ -z "${subnetId}" ]; then
    echo "Couldnt create Private Subnet ${subNetPrivateName}. Exiting..."
    exit 1
  fi
  subNetPrivateIds+=($subnetId)
  #name the subnet
  aws ec2 create-tags \
    --resources "$subnetId" \
    --region=$REGION \
    --tags Key=Name,Value="$subNetPrivateName" > /dev/null
  #disable public ip on subnet
  echo "Disabling IP on Private Subnet ${subNetPrivateName}..."
  modify_response=$(aws ec2 modify-subnet-attribute \
   --subnet-id "$subnetId" \
   --region=$REGION \
   --no-map-public-ip-on-launch)

   #create route table for vpc
   echo "Creating Route Table ${routeTablePrivateName}..."
   route_table_response=$(aws ec2 create-route-table \
     --vpc-id "$vpcId" \
     --region=$REGION \
     --output json)
   routeTablePrivateId=$(echo -e "$route_table_response" |  /usr/bin/jq '.RouteTable.RouteTableId' | tr -d '"')
   if [ -z "${routeTablePrivateId}" ]; then
     echo "Couldnt create Route Table ${routeTablePrivateName}. Exiting..."
     exit 1
   fi
   routeTablePrivateIds+=(${routeTablePrivateId})
   #name the route table
   aws ec2 create-tags \
    --resources "$routeTablePrivateId" \
    --region=$REGION \
    --tags Key=Name,Value="$routeTablePrivateName" > /dev/null
   #add route for the internet gateway
   echo "Creating Route to NAT in ${routeTablePrivateName}..."
   route_response=$(aws ec2 create-route \
     --route-table-id "$routeTablePrivateId" \
     --destination-cidr-block "$destinationCidrBlock" \
     --region=$REGION \
     --nat-gateway-id "$natGatewayId")
   #add route to subnet
   echo "Associating Route to Private Subnet ${subNetPrivateName}..."
   associate_response=$(aws ec2 associate-route-table \
     --subnet-id "$subnetId" \
     --region=$REGION \
     --route-table-id "$routeTablePrivateId")
done
