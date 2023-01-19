#! /bin/bash

#  Destroys new AWS API GW endpoint

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> ENV_NAME=<xxx>  REGION=<xxx>./destroy-apigw.sh
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

# Get lambda functions
lambdaFunctions=$(aws lambda list-functions \
 --region ${REGION} \
 | jq ".Functions[] | .FunctionName" \
 | tr -d '\"')

apiGwName=PNF3_Event_Prod_WS-${ENV_NAME,,}
apiGwId=$(aws apigatewayv2 get-apis \
 --region ${REGION} \
 | jq ".Items[] | select(.Name==\"${apiGwName}\") | .ApiId" \
 | tr -d '\"')

if [ -z "${apiGwId}" ]; then
  echo "API Gateway ${apiGwName} doesn't exist. Exiting..."
  exit 1
fi

for function in ${lambdaFunctions}; do
  if [[ "${function}" = "deleteConnectionFunction" || "${function}" = "registerConnectionFunction" || "${function}" = "syncBlockFunction" || "${function}" = "estimateGasFunction" ]]; then
    echo "Deleting permissions from lambda function ${function}..."
    aws lambda remove-permission \
     --region ${REGION} \
     --function-name ${function} \
     --statement-id "${function}-${apiGwId}" > /dev/null

    echo "Deleting lambda function ${function}..."
    aws lambda delete-function \
     --region ${REGION} \
     --function-name ${function} > /dev/null
  fi
done

echo -e "\nDestroy API Gateway ${apiGwName}..."

roleName=nightfall_lambda_iam_role_${ENV_NAME,,}
roleStatus=$(aws iam list-roles \
| jq ".Roles[] | select(.RoleName==\"${roleName}\") | .RoleName")

if [ -z "${roleStatus}" ]; then
  echo  "IAM Role ${roleName} doesnt exist. Exiting..."
  exit 1
fi
echo "Delete Role policies for IAM role ${roleName}..."

rolePolicyArns=$(aws iam list-attached-role-policies \
--role-name ${roleName} \
| jq ".AttachedPolicies[] | .PolicyArn" \
| tr -d '\"')

if [ "${rolePolicyArns}" ]; then
  for arn in ${rolePolicyArns}; do
    echo "Detach role policy ${arn} from ${roleName}..."
    aws iam detach-role-policy \
     --role-name ${roleName} \
     --policy-arn ${arn}
  done
fi

echo "Delete IAM role ${roleName}..."
aws iam delete-role \
--role-name ${roleName}


apiGwStatus=$(aws apigatewayv2 delete-api \
 --api-id ${apiGwId} \
 --region ${REGION})

apiGwId=$(aws apigatewayv2 get-apis \
 --region ${REGION} \
 | jq ".Items[] | select(.Name==\"${apiGwName}\") | .ApiId" \
 | tr -d '\"')

if [ "${apiGwId}" ]; then
  echo "API Gateway ${apiGwName} wasn't deleted. Exiting..."
  exit 1
fi

echo "API Gateway ${apiGwName} deleted..."