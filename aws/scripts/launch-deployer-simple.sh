#! /bin/bash

#  Starts assuming contracts were deployed sucessfully and performs some housekeeping copying files to AWS...

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxx> ./launch-deployer-simple.sh
#   where AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are the AWS credentials
#   and RELEASE is the tag for the container image. If not defined, it will be set to latest
#
#  Pre-reqs
#  - Script assumes that a Web3 node in ${BLOCKCHAIN_WS_HOST}:${BLOCKCHAIN_PORT} is running. It will wait 
#   until it can connect to it
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

aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_REPO}

# Check Web3 is running
set +e

# Check efs is mounted
EFS_INFO=$(df -h | grep ${EFS_MOUNT_POINT})
if [ -z "${EFS_INFO}" ]; then
  echo "EFS filesystem ${EFS_MOUNT_POINT} not mounted....exiting"
  exit 1
fi

mkdir -p ${EFS_MOUNT_POINT}/build
mkdir -p ${EFS_MOUNT_POINT}/proving_files
mkdir -p ${EFS_MOUNT_POINT}/.openzeppelin

VOLUMES=$PWD/../volumes/${RELEASE}

# Wait until deployer is finished to copy files
while true; do
   DEPLOYER=$(docker ps | grep ${ECR_REPO}/nightfall-deployer:${RELEASE} || true)
   if [ -z "${DEPLOYER}" ]; then
      md5deep -r -s -b ${VOLUMES}/build > hash.txt
      sudo mv hash.txt ${VOLUMES}/build
      md5deep -r -s -b ${VOLUMES}/proving_files > hash.txt
      sudo mv hash.txt ${VOLUMES}/proving_files
      md5deep -r -s -b ${VOLUMES}/.openzeppelin > hash.txt
      sudo mv hash.txt ${VOLUMES}/.openzeppelin
      echo "Copying contracts and proving files to S3 bucket"
      sudo cp -R ${VOLUMES}/proving_files/* ${EFS_MOUNT_POINT}/proving_files/ 
      sudo cp -R ${VOLUMES}/build/* ${EFS_MOUNT_POINT}/build/ 
      sudo cp -R ${VOLUMES}/.openzeppelin/* ${EFS_MOUNT_POINT}/.openzeppelin/ 
      # Delete deployer wallet contents
      aws s3 rm --recursive ${S3_BUCKET_DEPLOYER}
      aws s3 sync ${EFS_MOUNT_POINT}/build ${S3_BUCKET_DEPLOYER}/build 2> /dev/null
      aws s3 sync ${EFS_MOUNT_POINT}/proving_files ${S3_BUCKET_DEPLOYER}/proving_files 2> /dev/null
      aws s3 sync ${EFS_MOUNT_POINT}/.openzeppelin ${S3_BUCKET_DEPLOYER}/.openzeppelin 2> /dev/null
      cd ${EFS_MOUNT_POINT}/proving_files
      # Delete contents
      aws s3 rm --recursive ${S3_BUCKET_WALLET}/circuits
      echo -e "[" > ${VOLUMES}/proving_files/s3_hash.txt
      for PROVING_FILE_FOLDERS in * ; do
        if [ -d "${PROVING_FILE_FOLDERS}" ]; then
          aws s3 cp ${PROVING_FILE_FOLDERS}/${PROVING_FILE_FOLDERS}.zkey ${S3_BUCKET_WALLET}/circuits/${PROVING_FILE_FOLDERS}/${PROVING_FILE_FOLDERS}.zkey
          aws s3 cp ${PROVING_FILE_FOLDERS}/${PROVING_FILE_FOLDERS}_js/${PROVING_FILE_FOLDERS}.wasm ${S3_BUCKET_WALLET}/circuits/${PROVING_FILE_FOLDERS}/${PROVING_FILE_FOLDERS}.wasm
          HF_ZKEY=$(cat ${VOLUMES}/proving_files/hash.txt | grep ${PROVING_FILE_FOLDERS}.zkey | awk '{print $1}')
          HF_WASM=$(cat ${VOLUMES}/proving_files/hash.txt | grep ${PROVING_FILE_FOLDERS}.wasm | awk '{print $1}')
          CIRCUIT_HASH=$(cat circuithash.txt   \
             | jq ".[] | select(.circuitName == \"${PROVING_FILE_FOLDERS}\") | .circuitHash " \
             | tr -d '\"')
          echo -e "\t{" >> ${VOLUMES}/proving_files/s3_hash.txt
          echo -e "\t\t\"name\": \"${PROVING_FILE_FOLDERS}\","  >> ${VOLUMES}/proving_files/s3_hash.txt
          echo -e "\t\t\"zkh\": \"${HF_ZKEY}\"," >> ${VOLUMES}/proving_files/s3_hash.txt
          echo -e "\t\t\"zk\": \"circuits/${PROVING_FILE_FOLDERS}/${PROVING_FILE_FOLDERS}.zkey\"," >> ${VOLUMES}/proving_files/s3_hash.txt
          echo -e "\t\t\"wasmh\": \"${HF_WASM}\"," >> ${VOLUMES}/proving_files/s3_hash.txt
          echo -e "\t\t\"wasm\": \"circuits/${PROVING_FILE_FOLDERS}/${PROVING_FILE_FOLDERS}.wasm\"," >> ${VOLUMES}/proving_files/s3_hash.txt
          echo -e "\t\t\"hash\": \"${CIRCUIT_HASH:0:12}\"" >> ${VOLUMES}/proving_files/s3_hash.txt
          echo -e "\t}," >> ${VOLUMES}/proving_files/s3_hash.txt
        fi
      done
      #Remove last line
      sed -i '$d' ${VOLUMES}/proving_files/s3_hash.txt
      echo -e "\t}" >> ${VOLUMES}/proving_files/s3_hash.txt
      echo -e "]" >> ${VOLUMES}/proving_files/s3_hash.txt
      aws s3 cp ${VOLUMES}/proving_files/s3_hash.txt ${S3_BUCKET_WALLET}/s3_hash.txt 2> /dev/null
      break
   fi
   sleep 5 
done


# Stop Worker
echo "Stopping worker docker image..."
if [ "${WORKER}" ]; then
  docker stop worker 2> /dev/null;
fi

# Umount EFS
sleep 5
echo "Umounting EFS unit at ${EFS_MOUNT_POINT}..."
sudo umount -f -l ${EFS_MOUNT_POINT}
rmdir ${EFS_MOUNT_POINT}

# Delete existing mongodb data
echo "Deleting existing local mongoDb data..."
sudo rm -rf ${VOLUMES}/mongodb/*

echo "Deployer launched"
