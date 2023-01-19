#! /bin/bash

#  Creates new AWS Env file

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> ENV_NAME=<xxx>  REGION=<xxx>./create-envfile.sh
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
if [ ! -f ../env/aws.env ]; then
  echo "File ../env/aws.env doesn't exist. Exiting..."
  exit 1
fi
source ../env/aws.env

echo -e "\nCreating Env File ${ENV_FILE}..."
vpcId=$(aws ec2 describe-vpcs \
  --region $REGION \
  | jq ".Vpcs[] | select(.CidrBlock==\"10.48.0.0/16\") | .VpcId" \
  | tr -d '"')

if [ -z "${vpcId}" ]; then
  echo "Couldn't read VPC ID. Exiting..."
  exit 1
fi

apiGwName=PNF3_Event_Prod_WS-${ENV_NAME,,}
apiGwId=$(aws apigatewayv2 get-apis \
 --region ${REGION} \
 | jq ".Items[] | select(.Name==\"${apiGwName}\") | .ApiId" \
 | tr -d '\"')

if [ -z "${apiGwId}" ]; then
  echo "Couldn't read API Gw Id. Exiting..."
  exit 1
fi

# Create env file
cp ../env/template.env ${ENV_FILE}
if [ ! -f "${ENV_FILE}" ]; then
  echo "Couldnt create Env File ${ENV_FILE}. Exiting..."
  exit 1
fi

domainName=$(aws route53 get-hosted-zone \
   --id ${HOSTED_ZONE_ID} \
   | jq ".HostedZone.Name" | tr -d '\"' |  head -c-2)

if [ -z "${domainName}" ]; then
  echo "Couldn't retrieve domain name. Exiting..."
  exit 1
fi

perl -i -pe "s#TEMPLATE#${ENV_NAME}#g" ${ENV_FILE}
perl -i -pe "s#export ENVIRONMENT_NAME=.*#export ENVIRONMENT_NAME=${ENV_NAME}#g" ${ENV_FILE}
perl -i -pe "s#export DOMAIN_NAME=.*#export DOMAIN_NAME=${ENV_NAME,,}.${domainName}#g" ${ENV_FILE}
perl -i -pe "s#export REGION=.*#export REGION=${REGION}#g" ${ENV_FILE}
perl -i -pe "s#export VPC_ID=.*#export VPC_ID=${vpcId}#g" ${ENV_FILE}
perl -i -pe "s#export API_WS_SEND_ENDPOINT=.*#export API_WS_SEND_ENDPOINT=wss://${apiGwId}.execute-api.${REGION}.amazonaws.com/${ENV_NAME,,}#g" ${ENV_FILE}
perl -i -pe "s#export API_HTTPS_SEND_ENDPOINT=.*#export API_HTTPS_SEND_ENDPOINT=https://${apiGwId}.execute-api.${REGION}.amazonaws.com/${ENV_NAME,,}/#g" ${ENV_FILE}
perl -i -pe "s#export S3_BUCKET_WALLET=.*#export S3_BUCKET_WALLET=s3://${S3_WALLET_BUCKET}-${ENV_NAME,,}#g" ${ENV_FILE}
perl -i -pe "s#export S3_BUCKET_DEPLOYER=.*#export S3_BUCKET_DEPLOYER=s3://${S3_DEPLOYER_BUCKET}-${ENV_NAME,,}#g" ${ENV_FILE}
perl -i -pe "s#export S3_BUCKET_CLOUDFRONT=.*#export S3_BUCKET_CLOUDFRONT=s3://${S3_CLOUDFRONT_BUCKET}-${ENV_NAME,,}#g" ${ENV_FILE}

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
   perl -i -pe "s#export BACK${index1}_SUBNET_ID=.*#export BACK${index}_SUBNET_ID=${subnetId}#g" ${ENV_FILE}
done

efsName=Nightfall-${ENV_NAME,,}-EFS
efsId=$(aws efs describe-file-systems \
  --region $REGION \
  | jq ".FileSystems[] | select(.Name==\"${efsName}\") | .FileSystemId" \
  | tr -d '"')
if [ -z "${efsId}" ]; then
  echo "Couldnt create EFS. Exiting..."
  exit 1
fi 
perl -i -pe "s#export EFS_ID=.*#export EFS_ID=${efsId}#g" ${ENV_FILE}


securityGroupName=${ENV_NAME}-efs-sg
sgId=$(aws ec2 describe-security-groups \
 --region ${REGION} \
 | jq ".SecurityGroups[] | select(.GroupName==\"${securityGroupName}\") | .GroupId" \
 | tr -d '"')
if [ -z "${sgId}" ]; then
  echo "Couldnt find EFS Security Group ${securityGroupName}. Exiting..."
  exit 1
fi
perl -i -pe "s#export EFS_SG_ID=.*#export EFS_SG_ID=${sgId}#g" ${ENV_FILE}


efsIp=$(aws efs describe-mount-targets  \
  --file-system-id ${efsId} \
  --region $REGION \
  | jq ".MountTargets[] | select(.AvailabilityZoneName==\"${REGION}a\") | .IpAddress" \
  | tr -d '"')
if [ -z "${efsIp}" ]; then
  echo "Couldnt find EFS_IP for EFS FS ${efsId}. Exiting..."
  exit 1
fi
perl -i -pe "s#export EFS_IP=.*#export EFS_IP=${efsIp}#g" ${ENV_FILE}

docDbId=docdb-${ENV_NAME,,}1
perl -i -pe "s#export MONGO_ID=.*#export MONGO_ID=${docDbId}#g" ${ENV_FILE}

mongoUrl=$(aws docdb describe-db-clusters \
 --region $REGION \
 | jq ".DBClusters[] | select(.DBClusterIdentifier==\"${docDbId}\") | .Endpoint" \
 | tr -d '"')
if [ -z "${mongoUrl}" ]; then
  echo "Couldnt find URL for docDb $docDbId. Exiting..."
  exit 1
fi
perl -i -pe "s#export MONGO_URL=.*#export MONGO_URL=${mongoUrl}#g" ${ENV_FILE}

cidrBlock=$(aws ec2 describe-client-vpn-endpoints \
  --region $REGION \
  | jq ".ClientVpnEndpoints[] | select(.VpcId==\"${vpcId}\") | .ClientCidrBlock" \
  | tr -d '"' \
  | awk '{split($0,a,"."); print a[2]}')

if [ -z "${cidrBlock}" ]; then
  echo "Couldnt find CIDR block for VPN}. Exiting..."
  exit 1
fi
perl -i -pe "s#export VPN_IP_SEED=.*#export VPN_IP_SEED=10.${cidrBlock}#g" ${ENV_FILE}

