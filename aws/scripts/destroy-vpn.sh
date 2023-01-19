#! /bin/bash

#  Deletes AWS VPN endpoint

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> ENV_NAME=<xxx>  REGION=<xxx>./destroy-vpn.sh
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
  | jq ".Vpcs[] | select(.CidrBlock==\"10.48.0.0/16\") | .VpcId" \
  | tr -d '"')

if [ -z "${vpcId}" ]; then
  echo "Couldn't read VPC ID. Exiting..."
  echo 1
fi


echo -e "\nStart VPN Endpoint deletion..."
serverCertificateName=${ENV_NAME,,}-vpn-server-certificate
clientCertificateName=${ENV_NAME,,}-vpn-client-certificate
# delete certificates
certificateArns=$(aws acm list-certificates \
  --region $REGION \
  | jq '.CertificateSummaryList[].CertificateArn' \
  | tr -d '"')

for certificateArn in $certificateArns; do
  status=$(aws acm list-tags-for-certificate \
     --certificate-arn $certificateArn \
     --region $REGION \
     | jq ".Tags[] | select((.Key==\"${serverCertificateName}\") or (.Key==\"${clientCertificateName}\")) ")
  if [ "${status}" ]; then 
    echo "Deleting certificate ${certificateArn}..."
    aws acm delete-certificate  \
      --certificate-arn $certificateArn \
      --region $REGION
  fi
done

# delete vpn client endpoint
echo -n "Waiting for VPN Endpoint to be available..."
while true; do
  vpnId=$(aws ec2 describe-client-vpn-endpoints \
    --region $REGION \
    | jq ".ClientVpnEndpoints[] | select(.VpcId==\"${vpcId}\") | .ClientVpnEndpointId" \
    | tr -d '"')
  if [ "${vpnId}" ]; then  
    break
  fi
  echo -n "."
  sleep 10
done
echo ""

assocId=$(aws ec2 describe-client-vpn-target-networks \
  --region $REGION \
  --client-vpn-endpoint-id $vpnId \
  | jq ".ClientVpnTargetNetworks[] | select(.ClientVpnEndpointId==\"${vpnId}\") | .AssociationId" \
  | tr -d '"')

if [ "${assocId}" ]; then
  echo "Disassociating Client VPN Target Network ${assocId} from VPN ${vpnId}..."
  aws ec2 disassociate-client-vpn-target-network \
    --client-vpn-endpoint-id $vpnId \
    --association-id $assocId \
    --region $REGION > /dev/null
fi

if [ "${vpnId}" ]; then
  echo "Deleting VPN Endpoint ${vpnId}..."
  aws ec2  delete-client-vpn-endpoint \
    --client-vpn-endpoint-id $vpnId \
    --region $REGION > /dev/null
fi

certificateOutputName=nightfall-${ENV_NAME,,}.ovpn
if [ -f "../certificates/${certificateOutputName}" ]; then
  echo "Deleting certificate ${certificateOutputName}..." 
  rm ../certificates/${certificateOutputName}
fi

