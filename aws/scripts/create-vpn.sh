#! /bin/bash

#  Creates new VPN endpoint

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> ENV_NAME=<xxx>  REGION=<xxx>./create-vpn.sh
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

vpcId=$(aws ec2 describe-vpcs \
  --region $REGION \
  | jq ".Vpcs[] | select(.CidrBlock==\"${vpcCidrBlock}\") | select(.Tags[].Value==\"${ENV_NAME}-NightfallVPC\" or .Tags[].Value==\"${ENV_NAME^}-NightfallVPC\") | .VpcId" \
  | tr -d '"')

if [ -z "${vpcId}" ]; then
  echo "Couldn't read VPC ID. Exiting..."
  echo 1
fi

vpnStatus=$(aws ec2 describe-client-vpn-endpoints \
  --region $REGION  \
  | jq ".ClientVpnEndpoints[] | select(.VpcId==\"${vpcId}\")")
if [ "${vpnStatus}" ]; then
  echo "VPC ${vpcId} already contains one VPN Client Endpoint. Exiting..."
  exit 1
fi
#variables used in script:
VPN_CLIENT_CIDR=10.85.48.0/22

echo -e "\nVPN endpoint initialization in VPC ${vpcId}..."

echo "Downloading easy-rsa repo to generate certificates..."
mkdir -p ./tmp 
SCRIPTS_FOLDER=$PWD
cd tmp
git clone https://github.com/OpenVPN/easy-rsa.git
cd easy-rsa/easyrsa3
./easyrsa init-pki
./easyrsa --batch build-ca nopass
./easyrsa --batch build-server-full server nopass
./easyrsa --batch build-client-full client1.domain.tld nopass
CERTIFICATE_FOLDER=../../certificates

mkdir -p $CERTIFICATE_FOLDER
cp pki/ca.crt $CERTIFICATE_FOLDER
cp pki/issued/server.crt $CERTIFICATE_FOLDER
cp pki/private/server.key $CERTIFICATE_FOLDER
cp pki/issued/client1.domain.tld.crt $CERTIFICATE_FOLDER
cp pki/private/client1.domain.tld.key $CERTIFICATE_FOLDER
cd $CERTIFICATE_FOLDER

CERT=$(cat client1.domain.tld.crt | grep -Poz '(?<=-----BEGIN CERTIFICATE-----\n)(.|\n)*(?=-----END CERTIFICATE-----)')
KEY=$(cat client1.domain.tld.key | grep -Poz '(?<=-----BEGIN PRIVATE KEY-----\n)(.|\n)*(?=-----END PRIVATE KEY-----)')

serverCertificateName=${ENV_NAME,,}-vpn-server-certificate
echo "Importing server certificate ${serverCertificateName}..."
certificate_describe=$(aws acm import-certificate \
 --certificate fileb://server.crt \
 --private-key fileb://server.key \
 --certificate-chain fileb://ca.crt \
 --region $REGION \
 --tags Key=name,Value=${serverCertificateName})
serverCertificateArn=$(echo ${certificate_describe} \
  | jq '.CertificateArn' \
  | tr -d '"')

if [ -z "${serverCertificateArn}" ]; then
  echo "Couldnt import server certificate ${serverCertificateName}. Exiting..."
  exit 1
fi

clientCertificateName=${ENV_NAME,,}-vpn-client-certificate
echo "Importing client certificate ${clientCertificateName}..."
certificate_describe=$(aws acm import-certificate \
  --certificate fileb://client1.domain.tld.crt \
  --private-key fileb://client1.domain.tld.key \
  --certificate-chain fileb://ca.crt \
  --region $REGION \
  --tags Key=name,Value=${clientCertificateName})
clientCertificateArn=$(echo ${certificate_describe} \
  | jq '.CertificateArn' \
  | tr -d '"')
if [ -z "${clientCertificateArn}" ]; then
  echo "Couldnt import client certificate ${clientCertificateName}. Exiting..."
  exit 1
fi
cd $SCRIPTS_FOLDER
rm -rf tmp



groupId=$(aws ec2 describe-security-groups \
 --region $REGION \
 | jq ".SecurityGroups[] | select(.VpcId==\"${vpcId}\") | select(.GroupName==\"default\") | .GroupId" \
 | tr -d '"')
if [ -z "${groupId}" ]; then
  echo "Couldnt find default security group. Exiting..."
  exit 1
fi

echo -n "Creating VPN endpoint..."
vpnDescribe=$(aws ec2 create-client-vpn-endpoint \
  --client-cidr-block ${VPN_CLIENT_CIDR} \
  --region $REGION \
  --security-group-ids $groupId \
  --vpc-id ${vpcId} \
  --self-service-portal disabled \
  --server-certificate-arn ${serverCertificateArn} \
  --authentication-options Type=certificate-authentication,MutualAuthentication={ClientRootCertificateChainArn=${clientCertificateArn}} \
  --connection-log-options Enabled=false)

vpnId=$(echo $vpnDescribe | jq ".ClientVpnEndpointId" | tr -d '"')

if [ -z "${vpnId}" ]; then
  echo "Couldnt create VPN Endpoint. Exiting..."
  exit 1
fi
echo -n "${vpnId}"
echo ""
subnetId=$(aws ec2 describe-subnets  \
  --region ${REGION} \
  --filters "Name=vpc-id,Values=${vpcId}" \
  | jq ".Subnets[] | select(.CidrBlock==\"${subNetPrivateCidrBlocks[0]}\") |  .SubnetId"   \
  | tr -d '"')

if [ -z "${subnetId}" ]; then
  echo "Couldnt find subnet with CIDR block ${subNetPrivateCidrBlocks[0]} in VPC ${vpcId}. Exiting..."
  exit 1
fi

echo -n "Waiting to create VPN client..."
while true; do
  vpnId=$(aws ec2 describe-client-vpn-endpoints \
    --region $REGION \
    | jq ".ClientVpnEndpoints[] | select(.Status.Code==\"pending-associate\") | select(.VpcId==\"${vpcId}\") | .ClientVpnEndpointId" \
    | tr -d '"')
  if [ "${vpnId}" ]; then  
    break
  fi
  echo -n "."
  sleep 10
done
echo -n "${vpnId}"
echo ""

echo "Associating Trarget Network to VPN client ${vpnId}..."
aws ec2 associate-client-vpn-target-network \
  --client-vpn-endpoint-id ${vpnId} \
  --subnet-id ${subnetId} \
  --region $REGION > /dev/null

echo "Setting \"allow-all\" ingress rule to VPN client ${vpnId}..."
aws ec2 authorize-client-vpn-ingress \
  --client-vpn-endpoint-id ${vpnId} \
  --target-network-cidr 10.40.0.0/16 \
  --authorize-all-groups \
  --region $REGION \
  --description "allow all" > /dev/null
echo "Setting \"internet\" ingress rule to VPN client ${vpnId}..."
aws ec2 authorize-client-vpn-ingress \
  --client-vpn-endpoint-id ${vpnId} \
  --target-network-cidr 0.0.0.0/0 \
  --authorize-all-groups \
  --region $REGION \
  --description "internet" > /dev/null
echo "Creating Route to Subnet ${subnetId} in VPN client ${vpnId}..."
aws ec2 create-client-vpn-route \
  --client-vpn-endpoint-id ${vpnId} \
  --destination-cidr-block 0.0.0.0/0 \
  --target-vpc-subnet-id ${subnetId} \
  --description "internet" \
  --region $REGION > /dev/null

echo -n "Waiting for VPN client ${vpnId} to be available..."
while true; do
  vpnStatus=$(aws ec2 describe-client-vpn-endpoints \
    --region $REGION \
    | jq ".ClientVpnEndpoints[] | select(.Status.Code==\"available\") | select(.VpcId==\"${vpcId}\") | .ClientVpnEndpointId" \
    | tr -d '"')
  if [ "${vpnStatus}" ]; then
    break
  fi
  echo -n "."
  sleep 10
done
echo -n "OK"
echo ""

certificateOutputName=nightfall-${ENV_NAME,,}.ovpn
echo "Exporting VPN Client Configuration for ${certificateOutputName}..."
aws ec2 export-client-vpn-client-configuration \
  --client-vpn-endpoint-id ${vpnId} \
  --region $REGION \
  --output text > ../certificates/${certificateOutputName}

if [ ! -f "../certificates/${certificateOutputName}" ]; then
  echo "Couldnt create Certificate file ../certificates/${certificateOutputName}. Exiting..."
  exit 1
fi
perl -i -pe "s#cipher AES.*#cipher AES-256-GCM\ninactive 1800 10000000#g" ../certificates/${certificateOutputName}
perl -i -pe "s#reneg.*#\n#g" ../certificates/${certificateOutputName}
echo -e "\n<cert>\n-----BEGIN CERTIFICATE-----\n${CERT}\n-----END CERTIFICATE-----\n</cert>" >> ../certificates/${certificateOutputName}
echo -e "\n<key>\n-----BEGIN PRIVATE KEY-----\n${KEY}\n-----END PRIVATE KEY-----\n</key>" >> ../certificates/${certificateOutputName}
echo -e "\nreneg-sec 0\n" >> ../certificates/${certificateOutputName}