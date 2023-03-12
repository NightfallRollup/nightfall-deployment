#! /bin/bash

#  Runs AWS setup diagnostics

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxx> ./diagnose-setup.sh
#   where AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are the AWS credentials
#   
#  It 
#  Pre-reqs
#  - Script can only be executed from a server with access to Nightfall private subnet

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

aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_REPO} 2> /dev/null

# Check SW dependencies
# docker (without sudo)
DOCKER=$(which docker)
if [ -z "${DOCKER}" ]; then
  echo "docker............................ KO"
else
  echo "docker............................ OK"
fi

# [openvpn](https://openvpn.net/vpn-server-resources/installing-openvpn-access-server-on-a-linux-system/)
OPENVPN=$(which openvpn)
if [ -z "${OPENVPN}" ]; then
 echo "openvpn........................... KO";
else
 echo "openvpn........................... OK";
fi

# [aws cli v2.4.16+](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
AWS_CLI=$(which aws)
if [ -z "${AWS_CLI}" ]; then
  echo "aws-cli........................... KO"
else
  echo "aws-cli........................... OK"
  AWS_CLI_VERSION=$(aws --version | awk {'print $1'} |  awk '{split($0,a,"/") ; print a[2] }') 
  echo "aws-cli version ${AWS_CLI_VERSION} ........... recommended 2+"
fi

# [aws Session Manger plugin v1.2.295.0](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
AWS_SESSION_MANAGER=$(which session-manager-plugin)
if [ -z "${AWS_SESSION_MANAGER}" ]; then
  echo "aws-session-manager-plugin........ KO"
else
  echo "aws-session-manager-plugin........ OK"
fi

# aws-cdk (npm install -g aws-cdk)
AWS_CDK=$(npm list -g --depth 0 | grep aws-cdk | awk '{print $2}')
if [ -z "${AWS_CDK}" ]; then
  echo "aws-cdk........................... KO"
else
  echo "aws-cdk........................... OK"
fi


# [mongosh](https://docs.mongodb.com/mongodb-shell/install/)
MONGOSH=$(which mongosh)
if [ -z "${MONGOSH}" ]; then
  echo "mongosh........................... KO"
else
  echo "mongosh........................... OK"
fi

# jq
JQ=$(which jq)
if [ -z "${JQ}" ]; then
  echo "jq................................ KO"
else
  echo "jq................................ OK"
fi

# wget
WGET=$(which wget)
if [ -z "${WGET}" ]; then
  echo "wget............................... KO"
else
  echo "wget............................... OK"
fi
# node v16+
NODE=$(which node)
if [ -z "${NODE}" ]; then
  echo "nodejs............................ KO"
else
  echo "nodejs............................ OK"
  NODE_VERSION=$(node --version)
  echo "node version ${NODE_VERSION}............. recommended v16.17.0"
fi

# npm 
NPM=$(which npm)
if [ -z "${NPM}" ]; then
  echo "npm............................... KO"
else
  echo "npm............................... OK"
  NPM_VERSION=$(npm --version)
  echo "npm version ${NPM_VERSION}................ recommended 8.15.0"
fi

# tmux
TMUX=$(which tmux)
if [ -z "${TMUX}" ]; then
  echo "tmux ............................. KO"
else
  echo "tmux ............................. OK"
fi

# md5deep
MD5DEEP=$(which md5deep)
if [ -z "${MD5DEEP}" ]; then
  echo "md5deep .......................... KO"
else
  echo "md5deep .......................... OK"
fi

# Check Repos exist
REPOS=$(aws ecr describe-repositories --region ${REGION} | jq '.repositories[].repositoryUri' | grep nightfall | tr -d '"')
if [ "${REPOS}" ]; then
  echo "Repositories exist ............... OK"
else
  echo "Repositories exist ............... KO"
fi  

# Check VPN is connected
VPN_CONNECTED=$(ifconfig -a  | grep tun)
if [ "${VPN_CONNECTED}" ]; then
  # Check we are connected to the right VPN
  VPN_IP=$(ifconfig -a | awk '/tun/{f=1} f && /inet/ {print $2; exit}')
  VPN_IP_MATCH=$(echo ${VPN_IP} | grep ${VPN_IP_SEED})
  if [ "${VPN_IP_MATCH}" ];then
     echo "VPN connected .................... OK"
  else
    echo "VPN connected ..................... KO"
    echo "  Reason: Connected to different VPN (${VPN_IP}. Expecting ${VPN_IP_SEED}"
  fi
else
  echo "VPN connected ................... KO"
fi

# Check can access public web
wget -q --spider http://google.com
if [ $? -eq 0 ]; then
    echo "Web connectivity ................. OK"
else
    echo "Web connectivity ................. KO"
fi

# Check secrets
./check-secrets.sh
if [ $? -eq 0 ]; then
  echo "Secrets .......................... OK"
else
  echo "Secrets .......................... KO"
fi

# Check EFS is mounted and contains data
./mount-efs.sh > /dev/null
if [ $? -eq 0 ]; then
  EFS=$(df -h | grep ${EFS_MOUNT_POINT})
  if [ "${EFS}" ]; then
     echo "EFS .............................. OK"
  else
     echo "EFS .............................. KO"
  fi
else
  echo "EFS ....................... KO"
fi

# Check EFS structture
if [ -d ${EFS_MOUNT_POINT}/build ]; then
   echo "EFS /build ....................... OK"
else
   echo "EFS /build ....................... KO"
fi
if [ -d ${EFS_MOUNT_POINT}/build/contracts ]; then
   echo "EFS /build/contracts ............. OK"
else
   echo "EFS /build/contracts ............. KO"
fi
if [ -d ${EFS_MOUNT_POINT}/store ]; then
   echo "EFS /store ....................... OK"
else
   echo "EFS /store ....................... KO"
fi
if [ -d ${EFS_MOUNT_POINT}/proving_files ]; then
   echo "EFS /proving_files................ OK"
else
   echo "EFS /proving_files................ KO"
fi

# Check Document Db is running
DOCDB_STATUS=$(aws docdb describe-db-clusters --db-cluster-identifier ${MONGO_ID} | jq '.DBClusters[0].Status' | tr -d '"')
if [ "${DOCDB_STATUS}" != "available" ]; then
   echo "DocDb status ..................... KO"
else
   echo "DocDb status (${DOCDB_STATUS}) ......... OK"

# Check Access to Document Db
MONGO_USERNAME=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${MONGO_INITDB_ROOT_USERNAME_PARAM}" | jq '.Parameter.Value' | tr -d '"') 
MONGO_PASSWORD=$(aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT_NAME}/${MONGO_INITDB_ROOT_PASSWORD_PARAM}" --with-decryption | jq '.Parameter.Value' | tr -d '"') 
COMMAND='$set'
mongosh --host ${MONGO_URL}:27017 \
 --retryWrites=false\
 --username ${MONGO_USERNAME} \
 --password ${MONGO_PASSWORD} \
 --quiet \
 --eval "db.getMongo().use(\"${OPTIMIST_DB}\")" > /dev/null

  if [ $? -eq 0 ]; then
    echo "DocumentDB access ................ OK"
  else
    echo "DocumentDB access ................ KO"
  fi
fi

# Check DynamoDb is created and accessible
DYNAMODB_TABLE=${DYNAMODB_DOCUMENTDB_TABLE} ./read-dynamodb.sh &>/dev/null
if [ $? -eq 0 ]; then
  echo "Access DynamoDB .................. OK"
else
  echo "Access DynamoDB .................. KO"
  echo "   might be because you haven't run make deploy-contracts"
fi

# Check containers are up and running
STATUS=$(./status-service.sh optimist)
if [ "${STATUS}" = "Cluster not found" ]; then
  echo "Cluster (and services) ........... KO"
else
  echo "Cluster .......................... OK"
  
  # Wait until Web3 node is alive (admit errors)
  WEB3_RESPONSE=$(curl -f --write-out '%{http_code}' --silent --output output.txt \
    --location --request POST https://"${BLOCKCHAIN_WS_HOST}" \
    --header 'Content-Type: application/json' \
    --data-raw '{
       "jsonrpc":"2.0",
       "method":"eth_blockNumber",
       "params":[],
       "id":83
     }')
  if [ "${WEB3_RESPONSE}" -ge "200" ] && [ "${WEB3_RESPONSE}" -le "499" ]; then
    echo "Connect to ${BLOCKCHAIN_WS_HOST}............. OK"
  else
    echo "Connect to ${BLOCKCHAIN_WS_HOST}............. KO"
  fi
  rm -f ./output.txt

  # Check proposer is alive
  ## ADD PROPOSER HEADER
  PROPOSER_RESPONSE=$(curl https://"${PROPOSER_HOST}"/healthcheck 2> /dev/null | grep OK || true)
  if [ "${PROPOSER_RESPONSE}" ]; then
    echo "Conected to ${PROPOSER_HOST}.......... OK"
  else
    echo "Conected to ${PROPOSER_HOST}.......... KO"
  fi

  # Check optimist is alive
  OPTIMIST_RESPONSE=$(curl https://"${OPTIMIST_HTTP_HOST}"/contract-address/Shield 2> /dev/null | grep 0x || true)
  if [ "${OPTIMIST_RESPONSE}" ]; then
    echo "Connected to ${OPTIMIST_HTTP_HOST}..... OK"
  else
    echo "Connected to ${OPTIMIST_HTTP_HOST}..... KO"
  fi

  # Check publisher is alive
  PUBLISHER_RESPONSE=$(curl https://"${PUBLISHER_HOST}"/healthcheck 2> /dev/null | grep OK || true)
  if [ "${PUBLISHER_RESPONSE}" ]; then
    echo "Connected to ${PUBLISHER_HOST}........ OK"
  else
    echo "Connected to ${PUBLISHER_HOST}........ KO"
  fi

  # Check dashboarg is alive
  DASHBOARD_RESPONSE=$(curl https://"${DASHBOARD_HOST}"/healthcheck 2> /dev/null | grep OK || true)
  if [ "${DASHBOARD_RESPONSE}" ]; then
    echo "Connected to ${DASHBOARD_HOST}........ OK"
  else
    echo "Connected to ${DASHBOARD_HOST}........ KO"
  fi

  # Check challenger is alive
  CHALLENGER_RESPONSE=$(curl https://"${CHALLENGER_HOST}"/healthcheck 2> /dev/null | grep OK || true)
  if [ "${CHALLENGER_RESPONSE}" ]; then
    echo "Connected to ${CHALLENGER_HOST}....... OK"
  else
    echo "Connected to ${CHALLENGER_HOST}....... KO"
  fi

  # Check optimist txw is alive
  OPTIMIST_TX_WORKER_RESPONSE=$(curl https://"${OPTIMIST_TX_WORKER_HOST}"/healthcheck 2> /dev/null | grep OK || true)
  if [ "${OPTIMIST_TX_WORKER_RESPONSE}" ]; then
    echo "Connected to ${OPTIMIST_TX_WORKER_HOST}..... OK"
  else
    echo "Connected to ${OPTIMIST_TX_WORKER_HOST}..... KO"
  fi

  # Check optimist bpw is alive
  OPTIMIST_BP_WORKER_RESPONSE=$(curl https://"${OPTIMIST_BP_WORKER_HOST}"/healthcheck 2> /dev/null | grep OK || true)
  if [ "${OPTIMIST_BP_WORKER_RESPONSE}" ]; then
    echo "Connected to ${OPTIMIST_BP_WORKER_HOST}..... OK"
  else
    echo "Connected to ${OPTIMIST_BP_WORKER_HOST}..... KO"
  fi

  # Check optimist baw is alive
  OPTIMIST_BA_WORKER_RESPONSE=$(curl https://"${OPTIMIST_BA_WORKER_HOST}"/healthcheck 2> /dev/null | grep OK || true)
  if [ "${OPTIMIST_BA_WORKER_RESPONSE}" ]; then
    echo "Connected to ${OPTIMIST_BA_WORKER_HOST}..... OK"
  else
    echo "Connected to ${OPTIMIST_BA_WORKER_HOST}..... KO"
  fi
fi

