#! /bin/bash

#  Delete volumes associated to this env

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./delete-volumes.sh

# Export env variables
set -o allexport
source ../env/aws.env
if [ ! -f "../env/${RELEASE}.env" ]; then
   echo "Undefined RELEASE ${RELEASE}"
   exit 1
fi
source ../env/${RELEASE}.env

if [ -d "../volumes/${RELEASE}" ]; then
  rm -rf ../volumes/${RELEASE}
fi