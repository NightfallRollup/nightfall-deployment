#! /bin/bash

#  Creates new s3 bucket

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> ENV_NAME=<xxx>  REGION=<xxx>./create-bucket.sh
#   where AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are the AWS credentials
#   ENV_NAME is the environment to be created

if [ -z "${ENV_NAME}" ]; then
  echo "Invalid ENV_NAME. Exiting..."
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

function createS3Bucket() {
  bucketName=$1
  bucketStatus=$(aws s3 ls --region ${REGION} | grep $bucketName)
  if [ "${bucketStatus}" ]; then
    echo "S3 bucket ${bucketName} already exists. Exiting..."
    return
  fi
  
  echo "Creating S3 bucket ${bucketName}..."
  aws s3 mb s3://${bucketName} --region ${REGION} > /dev/null
  sleep 2
  bucketStatus=$(aws s3 ls | grep $bucketName)
  if [ -z "${bucketStatus}" ]; then
    echo "Couldn't create S3 bucket ${bucketName}..."
    return
  fi
  
  echo "Setting public access to ${bucketName}..."
  if [ ! -f ../aws/lib/policies/s3_bucket_public_policy.json ]; then
    echo "Couldnt find S3 bucket public policy at ../aws/lib/policies/s3_bucket_public_policy.json. Exiting..."
    return
  fi
  cp ../aws/lib/policies/s3_bucket_public_policy.json ./s3_bucket_policy.json
  
  if [ ! -f ./s3_bucket_policy.json ]; then
    echo "Couldnt copy S3 bucket public policy from ../aws/lib/policies/s3_bucket_public_policy.json to ./s3_bucket_policy.json. Exiting..."
    return
  fi
  
  perl -i -pe "s#.*Resource.*#\t\t\"Resource\": \"arn:aws:s3:::${bucketName}/*\"#g" ./s3_bucket_policy.json
  aws s3api put-bucket-policy \
    --bucket $bucketName \
    --policy file://./s3_bucket_policy.json > /dev/null
  rm ./s3_bucket_policy.json
  
  echo "Checking S3 bucket policy in ${bucketName}..."
  policy=$(aws s3api get-bucket-policy \
    --bucket ${bucketName})
  if [ -z "${policy}" ]; then
    echo "Couldnt set policy to S3 bucket ${bucketName}. Exiting..."
    return
  fi

  echo "Adding CORS policy in ${bucketName}..."
  aws s3api put-bucket-cors \
    --bucket ${bucketName} \
    --region ${REGION} \
    --cors-configuration file://../aws/lib/policies/s3_bucket_cors.json
}


walletBucketName=${S3_WALLET_BUCKET}-${ENV_NAME,,}
deployerBucketName=${S3_DEPLOYER_BUCKET}-${ENV_NAME,,}
cloudFrontBucketName=${S3_CLOUDFRONT_BUCKET}-${ENV_NAME,,}

createS3Bucket ${walletBucketName}
createS3Bucket ${deployerBucketName}
createS3Bucket ${cloudFrontBucketName}
