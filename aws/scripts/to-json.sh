#! /bin/bash

#  Convers env vars to json

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxxx> ./to-json.sh
#

# Export env variables
set -o allexport
source ../env/aws.env
if [ ! -f "../env/${RELEASE}.env" ]; then
   echo "Undefined RELEASE ${RELEASE}"
   exit 1
fi
source ../env/${RELEASE}.env
if [ "${DEPLOYER_ETH_NETWORK}" = "staging" ]; then
  SECRETS_ENV=../env/secrets-ganache.env
else
  SECRETS_ENV=../env/secrets.env
fi
source ${SECRETS_ENV}
set +o allexport

file_name=/tmp/jsonenv.env
out_file=${OUT_FILE}
if [ -z ${OUT_FILE} ]; then
  out_file=/tmp/envjson.json
fi
envsubst < "../env/${RELEASE}.env" > ${file_name}

last_line=$(wc -l < $file_name)
current_line=0

echo "{" > ${out_file}
while read line
do
  current_line=$(($current_line + 1))
  if [[ $current_line -ne $last_line ]]; then
  [ -z "$line" ] && continue
  [[ "$line" != *"export"* ]] && continue
    echo ${line:6}|awk -F'='  '{ print " \""$1"\" : \""$2"\","}'|grep -iv '\"#' | grep "${FILTER}" >> ${out_file}
  fi
done < $file_name
echo "\"LAST\" : \"\"" >> ${out_file}
echo "}" >> ${out_file}

rm -f "${file_name}"
