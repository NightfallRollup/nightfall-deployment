#! /bin/bash

#  Deletest new s3 bucket

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> ENV_NAME=<xxx>  REGION=<xxx>./create-bucket.sh
#   where AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are the AWS credentials
#   ENV_NAME is the environment to be created
#   REGION is the AWS region where bucket is removed


if [ -z "${ENV_NAME}" ]; then
  echo "Invalid Env name. Exiting..."
  exit 1
fi

if [ -z "${REGION}}" ]; then
  echo "Invalid REGION. Exiting..."
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

function destroyS3Bucket() {
  bucketName=$1
  bucketStatus=$(aws s3 ls --region ${REGION} | grep $bucketName)
  if [  "${bucketStatus}" ]; then
    echo "Deleting S3 bucket ${bucketName}..."
    aws s3 rm s3://${bucketName} --recursive --region ${REGION} > /dev/null
    aws s3 rb s3://${bucketName} --region ${REGION} > /dev/null
    sleep 2
    bucketStatus=$(aws s3 ls --region ${REGION}| grep $bucketName)
    if [ "${bucketStatus}" ]; then
      echo "Couldn't delete S3 bucket ${bucketName}..."
      exit 1
    fi
  fi
}
walletBucketName=${S3_WALLET_BUCKET}-${ENV_NAME,,}
deployerBucketName=${S3_DEPLOYER_BUCKET}-${ENV_NAME,,}
cloudFrontBucketName=${S3_CLOUDFRONT_BUCKET}-${ENV_NAME,,}

destroyS3Bucket ${walletBucketName}
destroyS3Bucket ${deployerBucketName}
destroyS3Bucket ${cloudFrontBucketName}