#! /bin/bash

#  Creates new AWS API GW endpoint

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> ENV_NAME=<xxx>  REGION=<xxx>./create-apigw.sh
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
source ../env/aws.env

echo -e "\nAPI Gateway initialization..."

if [ -z "${ETHERSCAN_API_KEY}" ]; then
 echo "Please configure ETHERSCAN_API_KEY. Exiting..."
 exit 1
fi

apiGwName=PNF3_Event_Prod_WS-${ENV_NAME,,}
apiGwStatus=$(aws apigatewayv2 get-apis \
 --region ${REGION} \
 | jq ".Items[] | select(.Name==\"${apiGwName}\") | .Name" \
 | tr -d '\"')

if [ "${apiGwStatus}" ]; then
  echo "API Gateway ${apiGwName} already exists. Exiting..."
  exit 1
fi

## Create IAM role
roleName=nightfall_lambda_iam_role_${ENV_NAME,,}

echo "Create IAM Role ${roleName}..."
roleStatus=$(aws iam list-roles \
| jq ".Roles[] | select(.RoleName==\"${roleName}\") | .RoleName")

if [ "${roleStatus}" ]; then
  echo  "IAM Role ${roleName} already exists. Exiting..."
  exit 1
fi
aws iam create-role \
--role-name ${roleName} \
--assume-role-policy-document file://../aws/lib/policies/lambda_policy.json > /dev/null

 
## Add AWS managed policy to the role for access to CloudWatch and DynamoDB
echo "Attach DynamoDBFullAccess policy to ${roleName}..."
aws iam attach-role-policy \
--role-name ${roleName} \
--policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess

echo "Attach Lambda full access policy to ${roleName}..."
aws iam attach-role-policy \
--role-name ${roleName} \
--policy-arn arn:aws:iam::aws:policy/AWSLambda_FullAccess

echo "Attach Lambda Invocation policy to ${roleName}..."
aws iam attach-role-policy \
--role-name ${roleName} \
--policy-arn arn:aws:iam::aws:policy/AWSLambdaInvocation-DynamoDB

echo "Attach AmazonAPIGatewayInvokeFullAccess policy to ${roleName}..."
aws iam attach-role-policy \
--role-name ${roleName} \
--policy-arn arn:aws:iam::aws:policy/AmazonAPIGatewayInvokeFullAccess

## Get the role ARN
ACCOUNT_ID=$(aws sts get-caller-identity | jq -r .Account)
IAM_ROLE_ARN=arn:aws:iam::$ACCOUNT_ID:role/${roleName}

## Zip the code
mkdir -p /tmp

mkdir -p /tmp/delete
cp ../aws/lib/lambdas/deleteConnectionProd.mjs /tmp/delete/index.js
cd /tmp/delete
zip /tmp/deleteConnectionFunction.zip ./index.js
cd -

mkdir -p /tmp/register
cp ../aws/lib/lambdas/registerConnectionProd.mjs /tmp/register/index.js
cd /tmp/register
zip /tmp/registerConnectionFunction.zip ./index.js
cd -

mkdir -p /tmp/sync
cp ../aws/lib/lambdas/syncBlockProd.mjs /tmp/sync/index.js
cd /tmp/sync
zip /tmp/syncBlockFunction.zip ./index.js
cd -

mkdir -p /tmp/estimate
cp ../aws/lib/lambdas/estimateGas.mjs /tmp/estimate/index.js
cd /tmp/estimate
zip /tmp/estimateGasFunction.zip ./index.js
cd -

sleep 10 
## Create lambda function
aws lambda create-function \
--function-name deleteConnectionFunction \
--region ${REGION} \
--runtime nodejs14.x \
--zip-file fileb:///tmp/deleteConnectionFunction.zip \
--handler index.handler \
--role $IAM_ROLE_ARN > /dev/null

aws lambda create-function \
--function-name registerConnectionFunction \
--region ${REGION} \
--runtime nodejs14.x \
--zip-file fileb:///tmp/registerConnectionFunction.zip \
--handler index.handler \
--role $IAM_ROLE_ARN > /dev/null

aws lambda create-function \
--function-name syncBlockFunction \
--region ${REGION} \
--runtime nodejs14.x \
--zip-file fileb:///tmp/syncBlockFunction.zip \
--handler index.handler \
--role $IAM_ROLE_ARN > /dev/null

aws lambda create-function \
--function-name estimateGasFunction \
--region ${REGION} \
--runtime nodejs14.x \
--zip-file fileb:///tmp/estimateGasFunction.zip \
--handler index.handler \
--role $IAM_ROLE_ARN > /dev/null

## Get lambda function ARN
deleteLambdaArn=$(aws lambda get-function \
--region ${REGION} \
--function-name  deleteConnectionFunction | jq -r .Configuration.FunctionArn) 
registerLambdaArn=$(aws lambda get-function \
--region ${REGION} \
--function-name  registerConnectionFunction | jq -r .Configuration.FunctionArn)
syncLambdaArn=$(aws lambda get-function \
--region ${REGION} \
--function-name  syncBlockFunction | jq -r .Configuration.FunctionArn)

## API Endpoint
echo "Creating API Gateway ${apiGwName}..."
apiEndpoint=$(aws apigatewayv2 create-api \
 --name ${apiGwName} \
 --region ${REGION} \
 --protocol-type WEBSOCKET \
 --route-selection-expression '$request.body.type' \
 | jq "select(.Name==\"${apiGwName}\") | .ApiEndpoint" \
 | tr -d '\"')

if [ -z "${apiEndpoint}" ]; then
  echo "API Gateway ${apiGwName} wasn't created. Exiting..."
  exit 1
fi

apiGwId=$(aws apigatewayv2 get-apis \
 --region ${REGION} \
 | jq ".Items[] | select(.Name==\"${apiGwName}\") | .ApiId" \
 | tr -d '\"')
echo "API Gateway ${apiGwName} with Id ${apiGwId} created..."

# Udate lambda sync to 512 M and add env variable
aws lambda update-function-configuration \
 --function-name syncBlockFunction \
 --region ${REGION} \
 --memory-size 512 \
 --environment "Variables={SEND_ENDPOINT=https://${apiGwId}.execute-api.${REGION}.amazonaws.com/}" > /dev/null 

aws lambda update-function-configuration \
 --function-name estimateGasFunction \
 --region ${REGION} \
 --environment "Variables={ETH_GAS_STATION=${ETHERSCAN_API_KEY}}" > /dev/null 

# Create API routes
apiGwDefaultId=$(aws apigatewayv2 create-route \
 --api-id ${apiGwId} \
 --region ${REGION} \
 --route-key '$default' \
 | jq ".RouteId" | tr -d '\"')
echo "Creating default route in API Gateway ${apiGwName} with id ${apiGwDefaultId}..."

apiGwConnectId=$(aws apigatewayv2 create-route \
 --api-id ${apiGwId} \
 --region ${REGION} \
 --route-key '$connect' \
 | jq ".RouteId" | tr -d '\"')
echo "Creating connect route in API Gateway ${apiGwName} with id ${apiGwConnectId}..."

apiGwDisconnectId=$(aws apigatewayv2 create-route \
 --api-id ${apiGwId} \
 --region ${REGION} \
 --route-key '$disconnect' \
 | jq ".RouteId" | tr -d '\"')
echo "Creating disconnect route in API Gateway ${apiGwName} with id ${apiGwDisconnectId}..."

apiGwSyncId=$(aws apigatewayv2 create-route \
 --api-id ${apiGwId} \
 --region ${REGION} \
 --route-key 'sync' \
 | jq ".RouteId" | tr -d '\"')
echo "Creating sync route in API Gateway ${apiGwName} with id ${apiGwSyncId}..."


apiGwDeleteIntegrationId=$(aws apigatewayv2 create-integration \
  --region ${REGION} \
  --api-id ${apiGwId} \
  --integration-type AWS_PROXY \
  --integration-method POST \
  --integration-uri arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${deleteLambdaArn}/invocations \
  | jq ".IntegrationId" \
  | tr -d '\"')
echo "Integration in API Gateway ${apiGwName} for Lambda ${deleteLambdaArn} created with id ${apiGwDeleteIntegrationId}..."

aws apigatewayv2 update-route \
  --region ${REGION} \
  --api-id ${apiGwId} \
  --route-id ${apiGwDisconnectId} \
  --target integrations/${apiGwDeleteIntegrationId} \
  --route-key '$disconnect' > /dev/null

apiGwRegisterIntegrationId=$(aws apigatewayv2 create-integration \
  --region ${REGION} \
  --api-id ${apiGwId} \
  --integration-type AWS_PROXY \
  --integration-method POST \
  --integration-uri arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${registerLambdaArn}/invocations \
  | jq ".IntegrationId" \
  | tr -d '\"')
echo "Integration in API Gateway ${apiGwName} for Lambda ${registerLambdaArn} created with id ${apiGwRegisterIntegrationId}..."

aws apigatewayv2 update-route \
  --region ${REGION} \
  --api-id ${apiGwId} \
  --route-id ${apiGwConnectId} \
  --target integrations/${apiGwRegisterIntegrationId} \
  --route-key '$connect' > /dev/null

apiGwSyncIntegrationId=$(aws apigatewayv2 create-integration \
  --region ${REGION} \
  --api-id ${apiGwId} \
  --integration-type AWS_PROXY \
  --integration-method POST \
  --integration-uri arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${syncLambdaArn}/invocations \
  | jq ".IntegrationId" \
  | tr -d '\"')
echo "Integration in API Gateway ${apiGwName} for Lambda ${registerLambdaArn} created with id ${apiGwSyncIntegrationId}..."

aws apigatewayv2 update-route \
  --region ${REGION} \
  --api-id ${apiGwId} \
  --route-id ${apiGwSyncId} \
  --target integrations/${apiGwSyncIntegrationId} \
  --route-key 'sync' > /dev/null

apiGwDefaultIntegrationId=$(aws apigatewayv2 create-integration \
  --region ${REGION} \
  --api-id ${apiGwId} \
  --integration-type MOCK \
  | jq ".IntegrationId" \
  | tr -d '\"')
echo "MOCK Integration in API Gateway ${apiGwName} created with id ${apiGwDefaultIntegrationId}..."

aws apigatewayv2 update-route \
  --region ${REGION} \
  --api-id ${apiGwId} \
  --route-id ${apiGwDefaultId} \
  --target integrations/${apiGwDefaultIntegrationId} \
  --route-key '$default' > /dev/null

apiGwDeploymentId=$(aws apigatewayv2 create-deployment \
  --region ${REGION} \
  --api-id ${apiGwId} \
  | jq ".DeploymentId" | tr -d '\"')
echo "Created deployment for API Gateway ${apiGwName} with id ${apiGwDeploymentId}..."

aws apigatewayv2 create-stage \
  --region ${REGION} \
  --api-id ${apiGwId} \
  --stage-name ${ENV_NAME} \
  --stage-variables "deployment=${ENV_NAME}" \
  --deployment-id ${apiGwDeploymentId} > /dev/null
echo "Created stage ${ENV_NAME} for API Gateway ${apiGwName}..."


## Enable API Gateway to access functions
aws lambda add-permission \
  --region ${REGION}  \
  --function-name deleteConnectionFunction \
  --statement-id "deleteConnectionFunction-${apiGwId}" \
  --action "lambda:InvokeFunction" \
  --principal "apigateway.amazonaws.com" \
  --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${apiGwId}/*" > /dev/null

aws lambda add-permission \
  --region ${REGION}  \
  --function-name registerConnectionFunction \
  --statement-id "registerConnectionFunction-${apiGwId}" \
  --action "lambda:InvokeFunction" \
  --principal "apigateway.amazonaws.com" \
  --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${apiGwId}/*" > /dev/null

aws lambda add-permission \
  --region ${REGION}  \
  --function-name syncBlockFunction \
  --statement-id "syncBlockFunction-${apiGwId}" \
  --action "lambda:InvokeFunction" \
  --principal "apigateway.amazonaws.com" \
  --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${apiGwId}/*" > /dev/null

aws lambda add-permission \
  --region ${REGION}  \
  --function-name estimateGasFunction \
  --statement-id "estimateGasFunction-${apiGwId}" \
  --action "lambda:InvokeFunction" \
  --principal "apigateway.amazonaws.com" \
  --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${apiGwId}/*" > /dev/null
