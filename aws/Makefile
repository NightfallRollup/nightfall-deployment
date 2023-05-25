#!/bin/bash

# Use: make release <VAR_NAME1=value1> <VAR_NAME2=value2> ....


# Specify NIGHTFALL REPO
# EYBlockchain/nightfall_3
# NightfallRollup/nightfall_3.5
NIGHTFALL_REPO=NightfallRollup/nightfall_3.5

##VERSIONS
# Specify git commit tag/branch. If unspecified, git commit will use current
# NIGHTFALL_BRANCH=7d6b132845013246b40dd2b6f067246eb1e6f451
NIGHTFALL_BRANCH=c3f36d59db7dc0a69f0466100224613084fe3878
OVERWRITE_CODE=y

### RELEASES
RELEASE_INTERNAL=internal
RELEASE_STAGING=staging
RELEASE_PREPROD=preprod
RELEASE_TESTNET=testnet
RELEASE_PROD=production
RELEASE_TMP=tmp-

ifeq ($(RELEASE),)
  $(error Undefined RELEASE)
endif

## Check release is configured and set region accordingly
export REGION=$(shell cat env/${RELEASE}.env | sed  -n -e 's/^export REGION=//p')
ifneq ($(RELEASE),$(RELEASE_PROD))
  ifneq ($(RELEASE),$(RELEASE_STAGING))
    ifneq ($(RELEASE),$(RELEASE_INTERNAL))
      ifneq ($(RELEASE),$(RELEASE_PREPROD))
        ifneq ($(RELEASE),$(RELEASE_TESTNET))
		  ifneq ($(findstring $(RELEASE_TMP),$(RELEASE)),$(RELEASE_TMP))
            $(error Undefined RELEASE ${RELEASE})
          else
		    _RELEASE = $(subst -, ,$(RELEASE))
		    _RELEASE_NAME = $(word 2 , $(_RELEASE))
			_RELEASE_NAME_UPPER=$(shell echo  "${_RELEASE_NAME}" | sed 's/.*/\u&/')
		    ENVIRONMENT=${RELEASE_TMP}${_RELEASE_NAME}
            $(shell aws configure set region ${REGION} )
          endif
        else
		  ENVIRONMENT=Testnet
          $(shell aws configure set region ${REGION} )
        endif
      else
	   ENVIRONMENT=Preprod
       $(shell aws configure set region ${REGION} )
      endif
    else
	  ENVIRONMENT=Internal
      $(shell aws configure set region ${REGION} )
    endif
  else
    ENVIRONMENT=Staging
    $(shell aws configure set region ${REGION} )
  endif
else
  ENVIRONMENT=Production
  TERMINATE ?= $(shell bash -c 'read  -p "Production environment. Do you want to continue [y/N] " PROMPT; echo $$PROMPT')
  ifneq ($(TERMINATE),y)
    $(error Stop command in Production env)
  endif
  $(shell aws configure set region ${REGION} )
endif

# Check if GETH or Local Geth are enabled
export DEPLOYER_ETH_NETWORK=$(shell cat env/${RELEASE}.env | sed  -n -e 's/^export DEPLOYER_ETH_NETWORK=//p')

# Check CLIENT_N
export CLIENT_N=$(shell cat env/${RELEASE}.env | sed  -n -e 's/^export CLIENT_N=//p')

# Check REGULATOR_N
export REGULATOR_N=$(shell cat env/${RELEASE}.env | sed  -n -e 's/^export REGULATOR_N=//p')

# Retrieve AWS Account ID
export ACCOUNT_ID=$(shell cat env/aws.env | sed  -n -e 's/^export ACCOUNT_ID=//p')

# RETRIEVE REGION from AWS config
export REGION_AWS=$(shell aws configure get region)
ifneq ($(REGION),$(REGION_AWS))
  $(error Undefined REGION)
endif

ECR_REPO=${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

export USER_AWS=$(shell aws configure get aws_access_key_id)
export RESERVED_ENV=$(shell aws ssm get-parameter --region ${REGION} --name "/${ENVIRONMENT}/Reserved_Env" | jq '.Parameter.Value' | tr -d "\"" | tr -d " ")
ifeq ($(FORCE_ENV_BYPASS),)
  ifneq ($(RESERVED_ENV),Available)
    ifneq ($(RESERVED_ENV),${USER_AWS})
      $(error Environment ${RELEASE} used by ${RESERVED_ENV})
    endif
  endif
endif

# Build context file if it doesnt exist
CONTEXT:=$(shell if [ ! -f "./aws/contexts/cdk.context.${RELEASE}.json" ]; then cd scripts && ENV_NAME=${RELEASE} REGION=${REGION} ./create-cdk-context.sh; fi)

# Deploy Infrastructure (Cloudformation stacks)
deploy-infra:
	@make cdk-context
	@make check-efs
	@make mount-efs
	@make umount-efs
	@make check-secrets
	@make start-db
	@make stop-infra
	cd scripts && RELEASE=${RELEASE} ./deploy-cdk.sh
	@make stop-infra
	@make start-infra

# Uninstall Infrastructure (Cloudformation stacks)
destroy-infra:
	@make cdk-context
	cd scripts && RELEASE=${RELEASE} ./destroy-cdk.sh
	@if [ "${STOP_DB}" ]; then\
	   make stop-db; \
    fi
	cd scripts && RELEASE=${RELEASE} ./delete-dynamodb.sh
	cd scripts && RELEASE=${RELEASE} ./delete-volumes.sh

# Deploy EC2 deployer instance
deploy-deployer:
	@make cdk-context
	cd scripts && RELEASE=${RELEASE} DEPLOYER_EC2=true ./deploy-cdk.sh

destroy-deployer:
	@make cdk-context
	cd scripts && RELEASE=${RELEASE} DEPLOYER_EC2=true ./destroy-cdk.sh

# Delete MongoDb
delete-db:
	cd scripts && RELEASE=${RELEASE} ./delete-db.sh

# Connect to MongoDb
connect-db:
	cd scripts && RELEASE=${RELEASE} ./connect-db.sh

# Export MongoDb
export-db:
	cd scripts && RELEASE=${RELEASE} ./export-db.sh

# Import MongoDb
import-db:
	cd scripts && RELEASE=${RELEASE} ./import-db.sh

# Start MongoDb
start-db:
	cd scripts && RELEASE=${RELEASE} ./start-db.sh
	cd scripts && RELEASE=${RELEASE} ./wait-db.sh start

# Inialize MongoDb
init-db:
	cd scripts && RELEASE=${RELEASE} ./init-db.sh || true

# Stop MongoDb
stop-db:
	cd scripts && RELEASE=${RELEASE} ./stop-db.sh

# upgrade MongoDb
upgrade-db:
	cd scripts && RELEASE=${RELEASE} INSTANCE_TYPE=${INSTANCE_TYPE} ./upgrade-db.sh

launch-admin:
	cd scripts && RELEASE=${RELEASE} ./launch-admin.sh

test-db:
	cd scripts && RELEASE=${RELEASE} ./test-db.sh

fill-db:
	cd scripts && RELEASE=${RELEASE} ./fill-db.sh

test-publisher:
	cd scripts && RELEASE=${RELEASE} ./test-publisher.sh

test-dashboard:
	cd scripts && RELEASE=${RELEASE} ./test-dashboard.sh

test-ws:
	cd scripts && RELEASE=${RELEASE} LAST_BLOCK=${LAST_BLOCK} ./test-ws.sh

test-transaction:
	cp test/user/transaction.mjs nightfall_3/cli/src
	cd scripts && RELEASE=${RELEASE} TX_TYPE=${TX_TYPE} ./test-tx.sh

kill-publisher:
	tmux kill-session -t ${RELEASE}-publisher

make-block:
	cd scripts && RELEASE=${RELEASE} ./make-block.sh

reserve-env:
	@aws ssm put-parameter --region ${REGION} --name "/${ENVIRONMENT}/Reserved_Env" --type "String" --value "${USER_AWS}" --overwrite > /dev/null

release-env:
	@aws ssm put-parameter --region ${REGION} --name "/${ENVIRONMENT}/Reserved_Env" --type "String" --value "Available" --overwrite > /dev/null

# Read dynamoDb: DYNAMODB_TABLE can be PNF3_DocumentDB
read-dynamodb:
	cd scripts && RELEASE=${RELEASE} DYNAMODB_TABLE=${DYNAMODB_TABLE} COMMAND=${COMMAND} ./read-dynamodb.sh

# Get alarms
get-alarms:
	cd scripts && RELEASE=${RELEASE} COMMAND=alarms ./read-dashboard.sh

# Get metrics
get-metrics:
	cd scripts && RELEASE=${RELEASE} COMMAND=metrics LIMIT=${LIMIT} ./read-dashboard.sh

# Flush alarms
flush-alarms:
	cd scripts && RELEASE=${RELEASE} COMMAND=flush-alarms ./read-dashboard.sh

# Flush metrics
flush-metrics:
	cd scripts && RELEASE=${RELEASE} COMMAND=flush-metrics ./read-dashboard.sh

# Deregister proposer
deregister-proposer:
	cp test/proposer/proposer-command.mjs nightfall_3/cli/src
	cd scripts && RELEASE=${RELEASE} PROPOSER_COMMAND=deregister ./proposer-command.sh

# Change proposer
change-proposer:
	cp test/proposer/proposer-command.mjs nightfall_3/cli/src
	cd scripts && RELEASE=${RELEASE} PROPOSER_COMMAND=change ./proposer-command.sh

# Register proposer
register-proposer:
	cp test/proposer/proposer-command.mjs nightfall_3/cli/src
	cd scripts && RELEASE=${RELEASE} PROPOSER_COMMAND=register ./proposer-command.sh

# Test contracts
test-contracts:
	cp -R test/contracts-cli nightfall_3/test
	cd scripts && RELEASE=${RELEASE} ./mount-efs.sh
	cd scripts && RELEASE=${RELEASE} ./test-contracts.sh

# Test contracts
test-admin:
	cd scripts && RELEASE=${RELEASE} ./mount-efs.sh
	cd scripts && RELEASE=${RELEASE} ./test-admin.sh

kill-test_contracts:
	tmux kill-session -t ${RELEASE}-test || true
	docker stop client worker

# Mnemonic
mnemonic:
	cp test/client/client-command.mjs nightfall_3/cli/src
	cd scripts && RELEASE=${RELEASE} CLIENT_COMMAND=mnemonic MNEMONIC="${MNEMONIC}" ./client-command.sh

fund-accounts:
	cp test/deployer/fund-accounts.mjs nightfall_3/cli/src
	cd scripts && RELEASE=${RELEASE} ./fund-accounts.sh

# Launch local ping pong test
test-ping_pong:
	mkdir -p nightfall_3/test/ping-pong-single
	cp test/ping-pong/* nightfall_3/test/ping-pong-single
	cd scripts && RELEASE=${RELEASE} TEST_LENGTH=${TEST_LENGTH} TEST=PING_PONG ./launch-test.sh

test-load:
	cp test/client/load.test.mjs nightfall_3/test/
	cd scripts && RELEASE=${RELEASE} TEST_LENGTH=${TEST_LENGTH} TEST=LOAD ./launch-test.sh

# Launch txw test
test-opt_txw:
	cp test/workers/tx-worker.test.mjs nightfall_3/test
	cd scripts && RELEASE=${RELEASE} TEST_LENGTH=${TEST_LENGTH} TEST=OPT_TXW ./launch-test.sh

test-rln:
	mkdir -p nightfall_3/test/rln
	cp test/colored-money-test/* nightfall_3/test/rln
	cd scripts && RELEASE=${RELEASE} TEST_LENGTH=${TEST_LENGTH} TEST=RLN ./launch-test.sh

deploy-rln:
	cd scripts && RELEASE=${RELEASE} ./deploy-rln.sh

add-entity-rln:
	cd scripts && RELEASE=${RELEASE} ./add-entity-rln.sh

launch-client:
	cd scripts && RELEASE=${RELEASE} ./mount-efs.sh
	cd scripts && RELEASE=${RELEASE}  TEST_LENGTH=${TEST_LENGTH} ./launch-client.sh

kill-client:
	tmux kill-session -t ${RELEASE}-client || true
	docker stop client client-bpw client-txw worker mongodb

ssh-edge:
	cd scripts && RELEASE=${RELEASE} INSTANCE_NAME=edge CDK_STACK=Apps ./ssh-ec2.sh

ssh-deployer:
	cd scripts && RELEASE=${RELEASE} INSTANCE_NAME=deployer CDK_STACK=Deployer ./ssh-ec2.sh

init-deployer:
	cd scripts && RELEASE=${RELEASE} INSTANCE_NAME=deployer CDK_STACK=Deployer SRC_FILE="../env/${RELEASE}.env ../env/aws.env" DST_FILE=/home/ubuntu/nightfall-deployment/aws/env ./scp-ec2.sh
	cd scripts && RELEASE=${RELEASE} INSTANCE_NAME=deployer CDK_STACK=Deployer SRC_FILE=../aws/contexts/cdk.context.${RELEASE}.json DST_FILE=/home/ubuntu/nightfall-deployment/aws/aws/contexts ./scp-ec2.sh
	cd scripts && RELEASE=${RELEASE} INSTANCE_NAME=deployer CDK_STACK=Deployer SRC_FILE=~/.aws/credentials DST_FILE=/home/ubuntu/.aws/credentials ./scp-ec2.sh
	cd scripts && RELEASE=${RELEASE} INSTANCE_NAME=deployer CDK_STACK=Deployer COMMAND='ssh-keyscan -H github.com >> .ssh/known_hosts' ./ssh-ec2.sh
	cd scripts && RELEASE=${RELEASE} INSTANCE_NAME=deployer CDK_STACK=Deployer COMMAND='cd /home/ubuntu/nightfall-deployment/aws/aws && npm i' ./ssh-ec2.sh
	cd scripts && RELEASE=${RELEASE} INSTANCE_NAME=deployer CDK_STACK=Deployer TGT_EC2=y SRC_FILE=/home/ubuntu/.ssh/id_ed25519.pub DST_FILE=../aws/keys/id_ed25519.pub ./scp-ec2.sh
	gh auth login --with-token < ./aws/keys/git-${RELEASE}.token
	gh ssh-key add ./aws/keys/id_ed25519.pub --title "deployer-${RELEASE}"
	

lazy-optimist-enable:
	curl -X POST ${URL}/challenger/enable -H 'Content-Type: application/json' -d '{"enable":true}'

lazy-optimist-disable:
	curl -X POST ${URL}/challenger/enable -H 'Content-Type: application/json' -d '{"enable":false}'

deploy-wallet:
	cd scripts && RELEASE=${RELEASE} ./deploy-wallet.sh

deploy-wallet-local:
	cd scripts && RELEASE=${RELEASE} ./deploy-wallet-local.sh

# Build all images (client, optimist, proposer, challenger, publisher, adversary)
build-all:
	$(eval NIGHTFALL_LEGACY=$(shell cat env/${RELEASE}.env | sed  -n -e 's/^export NIGHTFALL_LEGACY=//p'))
	if [ "${NIGHTFALL_LEGACY}" != "true" ]; then\
	  make build-client_txw; \
	  make build-client_auxw; \
	  make build-client_bpw; \
	  make build-opt_txw; \
	  make build-opt_bpw; \
	  make build-opt_baw; \
	fi
	@make update-repo
	@make build-client
	@make build-lazy_client
	@make build-optimist
	@make build-proposer
	@make build-worker
	@make build-deployer
	@make build-publisher
	@make build-challenger
	@make build-dashboard
	@make build-adversary
	@make build-admin

# Push images to docker repo (client, optimist, proposer, challenger, publisher, adversary)
push-all:
	@make login-ecr
	$(eval GIT_COMMIT=$(shell git rev-parse HEAD))
	$(eval NIGHTFALL_LEGACY=$(shell cat env/${RELEASE}.env | sed  -n -e 's/^export NIGHTFALL_LEGACY=//p'))
	if [ "${NIGHTFALL_LEGACY}" != "true" ]; then\
	  make push-image NIGHTFALL_IMAGE=nightfall-client_txw GIT_COMMIT=${GIT_COMMIT} ; \
	  make push-image NIGHTFALL_IMAGE=nightfall-client_auxw GIT_COMMIT=${GIT_COMMIT} ; \
	  make push-image NIGHTFALL_IMAGE=nightfall-client_bpw GIT_COMMIT=${GIT_COMMIT} ; \
	  make push-image NIGHTFALL_IMAGE=nightfall-opt_txw GIT_COMMIT=${GIT_COMMIT} ; \
	  make push-image NIGHTFALL_IMAGE=nightfall-opt_bpw GIT_COMMIT=${GIT_COMMIT} ; \
	  make push-image NIGHTFALL_IMAGE=nightfall-opt_baw GIT_COMMIT=${GIT_COMMIT} ; \
	fi
	@make push-image NIGHTFALL_IMAGE=nightfall-publisher GIT_COMMIT=${GIT_COMMIT}
	@make push-image NIGHTFALL_IMAGE=nightfall-dashboard GIT_COMMIT=${GIT_COMMIT}
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make push-image NIGHTFALL_IMAGE=nightfall-client GIT_COMMIT=${GIT_COMMIT}
	@make push-image NIGHTFALL_IMAGE=nightfall-lazy_client GIT_COMMIT=${GIT_COMMIT}
	@make push-image NIGHTFALL_IMAGE=nightfall-optimist GIT_COMMIT=${GIT_COMMIT}
	@make push-image NIGHTFALL_IMAGE=nightfall-proposer GIT_COMMIT=${GIT_COMMIT}
	@make push-image NIGHTFALL_IMAGE=nightfall-worker GIT_COMMIT=${GIT_COMMIT}
	@make push-image NIGHTFALL_IMAGE=nightfall-deployer GIT_COMMIT=${GIT_COMMIT}
	@make push-image NIGHTFALL_IMAGE=nightfall-challenger GIT_COMMIT=${GIT_COMMIT}
	@make push-image NIGHTFALL_IMAGE=nightfall-adversary GIT_COMMIT=${GIT_COMMIT}
	@make push-image NIGHTFALL_IMAGE=nightfall-admin GIT_COMMIT=${GIT_COMMIT}

# Build individual images
build-client:
	@cp docker/client-docker-entrypoint.sh nightfall_3/nightfall-client/docker-entrypoint.sh
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make build-image NIGHTFALL_IMAGE=nightfall-client GIT_COMMIT=${GIT_COMMIT}

build-client_txw:
	@cp docker/docker-client-tx-worker-entrypoint.sh nightfall_3/nightfall-client/docker-client-tx-worker-entrypoint.sh
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make build-image NIGHTFALL_IMAGE=nightfall-client_txw GIT_COMMIT=${GIT_COMMIT}

build-client_auxw:
	@cp docker/docker-client-aux-worker-entrypoint.sh nightfall_3/nightfall-client/docker-client-aux-worker-entrypoint.sh
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make build-image NIGHTFALL_IMAGE=nightfall-client_auxw GIT_COMMIT=${GIT_COMMIT}

build-client_bpw:
	@cp docker/docker-client-bp-worker-entrypoint.sh nightfall_3/nightfall-client/docker-client-bp-worker-entrypoint.sh
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make build-image NIGHTFALL_IMAGE=nightfall-client_bpw GIT_COMMIT=${GIT_COMMIT}

build-optimist:
	@cp docker/optimist-docker-entrypoint.sh nightfall_3/nightfall-optimist/docker-entrypoint.sh
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make build-image NIGHTFALL_IMAGE=nightfall-optimist GIT_COMMIT=${GIT_COMMIT}

build-opt_txw:
	@cp docker/docker-optimist-tx-submitted-worker-entrypoint.sh nightfall_3/nightfall-optimist/docker-tx-submitted-entrypoint.sh
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make build-image NIGHTFALL_IMAGE=nightfall-opt_txw GIT_COMMIT=${GIT_COMMIT}

build-opt_bpw:
	@cp docker/docker-optimist-block-proposed-worker-entrypoint.sh nightfall_3/nightfall-optimist/docker-block-proposed-entrypoint.sh
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make build-image NIGHTFALL_IMAGE=nightfall-opt_bpw GIT_COMMIT=${GIT_COMMIT}

build-opt_baw:
	@cp docker/docker-optimist-block-assembly-worker-entrypoint.sh nightfall_3/nightfall-optimist/docker-block-assembly-entrypoint.sh
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make build-image NIGHTFALL_IMAGE=nightfall-opt_baw GIT_COMMIT=${GIT_COMMIT}

build-adversary:
	@cp docker/adversary.Dockerfile nightfall_3/docker
	@cp docker/optimist-docker-entrypoint.sh nightfall_3/nightfall-optimist/docker-entrypoint.sh
	perl -i -pe 's#^test$$# #g' ./nightfall_3/.dockerignore
	@cd nightfall_3 && npm run build-adversary
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make build-image NIGHTFALL_IMAGE=nightfall-adversary GIT_COMMIT=${GIT_COMMIT}

build-lazy_client:
	@cp docker/client-docker-entrypoint.sh nightfall_3/nightfall-client/docker-entrypoint.sh
	@cp docker/lazy_client.Dockerfile nightfall_3/docker
	perl -i -pe 's#^test$$# #g' ./nightfall_3/.dockerignore
	@cd nightfall_3 && npm run build-adversary
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make build-image NIGHTFALL_IMAGE=nightfall-lazy_client GIT_COMMIT=${GIT_COMMIT}

build-proposer:
	cp docker/proposer-docker-entrypoint.sh nightfall_3/apps/proposer/docker-entrypoint.sh
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make build-image NIGHTFALL_IMAGE=nightfall-proposer GIT_COMMIT=${GIT_COMMIT}

build-worker:
	make login-ecr
	@make build-circom
	@make build-rapidsnark
	cp docker/worker.Dockerfile nightfall_3/docker/worker.Dockerfile
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make build-image NIGHTFALL_IMAGE=nightfall-worker GIT_COMMIT=${GIT_COMMIT}

build-deployer:
	@cp docker/deployer-docker-entrypoint.sh nightfall_3/nightfall-deployer/entrypoint.sh
	$(eval CHALLENGE_PERIOD_AMOUNT=$(shell cat env/${RELEASE}.env | sed  -n -e 's/^export CHALLENGE_PERIOD_AMOUNT=//p'))
	$(eval CHALLENGE_PERIOD_UNIT=$(shell cat env/${RELEASE}.env | sed  -n -e 's/^export CHALLENGE_PERIOD_UNIT=//p'))
	perl -i -pe's#CHALLENGE_PERIOD.*#CHALLENGE_PERIOD = ${CHALLENGE_PERIOD_AMOUNT} ${CHALLENGE_PERIOD_UNIT};#g' nightfall_3/nightfall-deployer/contracts/Config.sol
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make build-image NIGHTFALL_IMAGE=nightfall-deployer GIT_COMMIT=${GIT_COMMIT}

build-challenger:
	cp docker/challenger.Dockerfile nightfall_3/docker
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make build-image NIGHTFALL_IMAGE=nightfall-challenger GIT_COMMIT=${GIT_COMMIT}

build-admin:
	cp docker/admin-docker-entrypoint.sh nightfall_3/nightfall-administrator/docker-entrypoint.sh
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make build-image NIGHTFALL_IMAGE=nightfall-admin GIT_COMMIT=${GIT_COMMIT}

build-publisher:
	$(eval GIT_COMMIT=$(shell git rev-parse HEAD))
	@make build-service-image SERVICE=publisher NIGHTFALL_IMAGE=nightfall-publisher GIT_COMMIT=${GIT_COMMIT}

build-dashboard:
	cp aws/lib/application/options.js ./services/dashboard/options.js
	perl -i -pe's#module.exports.*#export {#g' ./services/dashboard/options.js
	$(eval GIT_COMMIT=$(shell git rev-parse HEAD))
	@make build-service-image SERVICE=dashboard NIGHTFALL_IMAGE=nightfall-dashboard GIT_COMMIT=${GIT_COMMIT}

build-geth:
	cp nightfall_3/config/default.js services/geth/config
	cd services/geth && docker build -f geth.Dockerfile . -t ${ECR_REPO}/geth:${RELEASE}

build-circom:
	cd nightfall_3 && docker build -f docker/circom.Dockerfile . -t nightfall-circom:latest

build-rapidsnark:
	cd nightfall_3 && docker build -f docker/rapidsnark.Dockerfile . -t nightfall-rapidsnark:latest

# Push individual images to ECR
push-client:
	@make login-ecr
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make push-image NIGHTFALL_IMAGE=nightfall-client GIT_COMMIT=${GIT_COMMIT}

push-client_txw:
	@make login-ecr
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make push-image NIGHTFALL_IMAGE=nightfall-client_txw GIT_COMMIT=${GIT_COMMIT}

push-client_auxw:
	@make login-ecr
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make push-image NIGHTFALL_IMAGE=nightfall-client_auxw GIT_COMMIT=${GIT_COMMIT}

push-client_bpw:
	@make login-ecr
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make push-image NIGHTFALL_IMAGE=nightfall-client_bpw GIT_COMMIT=${GIT_COMMIT}

push-optimist:
	@make login-ecr
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make push-image NIGHTFALL_IMAGE=nightfall-optimist GIT_COMMIT=${GIT_COMMIT}

push-opt_txw:
	@make login-ecr
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make push-image NIGHTFALL_IMAGE=nightfall-opt_txw GIT_COMMIT=${GIT_COMMIT}

push-opt_bpw:
	@make login-ecr
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make push-image NIGHTFALL_IMAGE=nightfall-opt_bpw GIT_COMMIT=${GIT_COMMIT}

push-opt_baw:
	@make login-ecr
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make push-image NIGHTFALL_IMAGE=nightfall-opt_baw GIT_COMMIT=${GIT_COMMIT}

push-admin:
	@make login-ecr
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make push-image NIGHTFALL_IMAGE=nightfall-admin GIT_COMMIT=${GIT_COMMIT}

push-adversary:
	@make login-ecr
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make push-image NIGHTFALL_IMAGE=nightfall-adversary GIT_COMMIT=${GIT_COMMIT}

push-lazy_client:
	@make login-ecr
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make push-image NIGHTFALL_IMAGE=nightfall-lazy_client GIT_COMMIT=${GIT_COMMIT}

push-worker:
	@make login-ecr
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make push-image NIGHTFALL_IMAGE=nightfall-worker GIT_COMMIT=${GIT_COMMIT}

push-deployer:
	@make login-ecr
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make push-image NIGHTFALL_IMAGE=nightfall-deployer GIT_COMMIT=${GIT_COMMIT}

push-proposer:
	@make login-ecr
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make push-image NIGHTFALL_IMAGE=nightfall-proposer GIT_COMMIT=${GIT_COMMIT}

push-challenger:
	@make login-ecr
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make push-image NIGHTFALL_IMAGE=nightfall-challenger GIT_COMMIT=${GIT_COMMIT}

push-publisher:
	@make login-ecr
	$(eval GIT_COMMIT=$(shell git rev-parse HEAD))
	@make push-image NIGHTFALL_IMAGE=nightfall-publisher GIT_COMMIT=${GIT_COMMIT}

push-dashboard:
	@make login-ecr
	$(eval GIT_COMMIT=$(shell git rev-parse HEAD))
	@make push-image NIGHTFALL_IMAGE=nightfall-dashboard GIT_COMMIT=${GIT_COMMIT}

push-geth:
	@make login-ecr
	@docker push ${ECR_REPO}/geth:${RELEASE}

# Stop services
stop-infra:
	make stop-optimist
	make stop-opt_txw
	make stop-opt_bpw
	make stop-opt_baw
	make stop-proposer
	make stop-publisher
	make stop-dashboard
	make stop-challenger
	make stop-worker
	make stop-client
	make stop-client_txw
	make stop-client_auxw
	make stop-client_bpw
	make stop-regulator
	make stop-regulator_auxw
	make stop-regulator_bpw
	#make stop-geth

stop-optimist:
	cd scripts && RELEASE=${RELEASE} ./restart-task.sh optimist${INSTANCE_INDEX}
	cd scripts && RELEASE=${RELEASE} ./stop-service.sh optimist${INSTANCE_INDEX}

stop-opt_txw:
	cd scripts && RELEASE=${RELEASE} ./restart-task.sh opt_txw${INSTANCE_INDEX}
	cd scripts && RELEASE=${RELEASE} ./stop-service.sh opttxw${INSTANCE_INDEX}

stop-opt_bpw:
	cd scripts && RELEASE=${RELEASE} ./restart-task.sh opt_bpw${INSTANCE_INDEX}
	cd scripts && RELEASE=${RELEASE} ./stop-service.sh optbpw${INSTANCE_INDEX}

stop-opt_baw:
	cd scripts && RELEASE=${RELEASE} ./restart-task.sh opt_baw${INSTANCE_INDEX}
	cd scripts && RELEASE=${RELEASE} ./stop-service.sh optbaw${INSTANCE_INDEX}

stop-proposer:
	cd scripts && RELEASE=${RELEASE} ./restart-task.sh proposer${INSTANCE_INDEX}
	cd scripts && RELEASE=${RELEASE} ./stop-service.sh proposer${INSTANCE_INDEX}

stop-publisher:
	cd scripts && RELEASE=${RELEASE} ./restart-task.sh publisher
	cd scripts && RELEASE=${RELEASE} ./stop-service.sh publisher

stop-dashboard:
	cd scripts && RELEASE=${RELEASE} ./restart-task.sh dashboard
	cd scripts && RELEASE=${RELEASE} ./stop-service.sh dashboard

stop-challenger:
	cd scripts && RELEASE=${RELEASE} ./restart-task.sh challenger${INSTANCE_INDEX}
	cd scripts && RELEASE=${RELEASE} ./stop-service.sh challenger${INSTANCE_INDEX}

stop-geth:
	cd scripts && RELEASE=${RELEASE} ./restart-task.sh geth
	cd scripts && RELEASE=${RELEASE} ./stop-service.sh geth

stop-worker:
	cd scripts && RELEASE=${RELEASE} ./restart-task.sh circom${INSTANCE_INDEX}
	cd scripts && RELEASE=${RELEASE} ./stop-service.sh circom${INSTANCE_INDEX}

stop-client:
	cd scripts && RELEASE=${RELEASE} ./restart-task.sh client${INSTANCE_INDEX}
	cd scripts && RELEASE=${RELEASE} ./stop-service.sh client${INSTANCE_INDEX}

stop-client_txw:
	cd scripts && RELEASE=${RELEASE} ./restart-task.sh client_txw${INSTANCE_INDEX}
	cd scripts && RELEASE=${RELEASE} ./stop-service.sh clienttxw${INSTANCE_INDEX}

stop-client_auxw:
	cd scripts && RELEASE=${RELEASE} ./restart-task.sh client_aux${INSTANCE_INDEX}
	cd scripts && RELEASE=${RELEASE} ./stop-service.sh clientaux${INSTANCE_INDEX}

stop-client_bpw:
	cd scripts && RELEASE=${RELEASE} ./restart-task.sh client_bpw${INSTANCE_INDEX}
	cd scripts && RELEASE=${RELEASE} ./stop-service.sh clientbpw${INSTANCE_INDEX}

stop-regulator:
	cd scripts && RELEASE=${RELEASE} ./restart-task.sh regulator${INSTANCE_INDEX}
	cd scripts && RELEASE=${RELEASE} ./stop-service.sh regulator${INSTANCE_INDEX}

stop-regulator_auxw:
	cd scripts && RELEASE=${RELEASE} ./restart-task.sh reg_aux${INSTANCE_INDEX}
	cd scripts && RELEASE=${RELEASE} ./stop-service.sh regaux${INSTANCE_INDEX}

stop-regulator_bpw:
	cd scripts && RELEASE=${RELEASE} ./restart-task.sh reg_bpw${INSTANCE_INDEX}
	cd scripts && RELEASE=${RELEASE} ./stop-service.sh regbpw${INSTANCE_INDEX}

# Start services
start-infra_all:
	make start-optimist
	make start-opt_txw
	make start-opt_bpw
	make start-opt_baw
	make start-proposer
	make start-publisher
	make start-dashboard
	make start-challenger
	@if [ "${DEPLOYER_ETH_NETWORK}" = "staging" ]; then\
	   make start-geth; \
	else \
	  echo "Local Geth service is disabled"; \
    fi
	@if [ "${CLIENT_N}" ] && [ "${CLIENT_N}" != "0" ]; then\
	  make start-worker; \
	  make start-client; \
	  make start-client_txw; \
	  make start-client_auxw; \
	  make start-client_bpw; \
    else \
	  echo "Client service is disabled"; \
    fi
	@if [ "${REGULATOR_N}" ] && [ "${REGULATOR_N}" != "0" ]; then\
	  make start-regulator; \
	  make start-reglator_auxw; \
	  make start-regulator_bpw; \
    else \
	  echo "Regulator service is disabled"; \
    fi

start-infra:
	cd scripts && RELEASE=${RELEASE} ./start-infra.sh

start-optimist:
	cd scripts && RELEASE=${RELEASE} ./start-service.sh optimist${INSTANCE_INDEX}

start-opt_txw:
	cd scripts && RELEASE=${RELEASE} NEW_DESIRED_COUNT=${NEW_DESIRED_COUNT} ./start-service.sh opttxw${INSTANCE_INDEX}

start-opt_bpw:
	cd scripts && RELEASE=${RELEASE} ./start-service.sh optbpw${INSTANCE_INDEX}

start-opt_baw:
	cd scripts && RELEASE=${RELEASE} ./start-service.sh optbaw${INSTANCE_INDEX}

start-proposer:
	cd scripts && RELEASE=${RELEASE} ./start-service.sh proposer${INSTANCE_INDEX}

start-publisher:
	cd scripts && RELEASE=${RELEASE} ./start-service.sh publisher

start-dashboard:
	cd scripts && RELEASE=${RELEASE} ./start-service.sh dashboard

start-challenger:
	cd scripts && RELEASE=${RELEASE} ./start-service.sh challenger${INSTANCE_INDEX}

start-worker:
	cd scripts && RELEASE=${RELEASE} NEW_DESIRED_COUNT=${NEW_DESIRED_COUNT} ./start-service.sh circom${INSTANCE_INDEX}

start-client:
	cd scripts && RELEASE=${RELEASE} ./start-service.sh client${INSTANCE_INDEX}

start-client_txw:
	cd scripts && RELEASE=${RELEASE} NEW_DESIRED_COUNT=${NEW_DESIRED_COUNT} ./start-service.sh clienttxw${INSTANCE_INDEX}

start-client_auxw:
	cd scripts && RELEASE=${RELEASE} NEW_DESIRED_COUNT=${NEW_DESIRED_COUNT} ./start-service.sh clientaux${INSTANCE_INDEX}

start-client_bpw:
	cd scripts && RELEASE=${RELEASE} ./start-service.sh clientbpw${INSTANCE_INDEX}

start-regulator:
	cd scripts && RELEASE=${RELEASE} ./start-service.sh regulator${INSTANCE_INDEX}

start-regulator_auxw:
	cd scripts && RELEASE=${RELEASE} NEW_DESIRED_COUNT=${NEW_DESIRED_COUNT} ./start-service.sh regaux${INSTANCE_INDEX}

start-regulator_bpw:
	cd scripts && RELEASE=${RELEASE} ./start-service.sh regbpw${INSTANCE_INDEX}

start-geth:
	@if [ "${DEPLOYER_ETH_NETWORK}" = "staging" ]; then\
	  cd scripts && RELEASE=${RELEASE} ./start-service.sh geth; \
	else \
	  echo "Local Geth service is disabled"; \
    fi

# Restart tasks
restart-infra:
	make stop-infra
	@if [ "${DEPLOYER_ETH_NETWORK}" = "staging" ]; then\
	  make start-geth; \
    fi
	make start-infra

restart-optimist:
	make stop-optimist
	make start-optimist

restart-opt_txw:
	make stop-opt_txw
	make start-opt_txw

restart-opt_bpw:
	make stop-opt_bpw
	make start-opt_bpw

restart-opt_baw:
	make stop-opt_baw
	make start-opt_baw

restart-proposer:
	make stop-proposer
	make start-proposer

restart-challenger:
	make stop-challenger
	make start-challenger

restart-publisher:
	make stop-publisher
	make start-publisher

restart-dashboard:
	make stop-dashboard
	make start-dashboard

restart-geth:
	make stop-geth;
	@if [ "${DEPLOYER_ETH_NETWORK}" = "staging" ]; then\
	  make start-geth; \
	else \
	  echo "Local Geth service is disabled"; \
    fi

restart-client:
	make stop-client
	make start-client

restart-client_txw:
	make stop-client_txw
	make start-client_txw

restart-client_auxw:
	make stop-client_auxw
	make start-client_auxw

restart-client_bpw:
	make stop-client_bpw
	make start-client_bpw

restart-worker:
	make stop-worker
	make start-worker

restart-regulator:
	make stop-regulator
	make start-regulator

restart-regulator_auxw:
	make stop-regulator_auxw
	make start-regulator_auxw

restart-regulator_bpw:
	make stop-regulator_bpw
	make start-regulator_bpw

# Get task status
status-optimist:
	cd scripts && RELEASE=${RELEASE} ./status-service.sh optimist${INSTANCE_INDEX}
	cd scripts && RELEASE=${RELEASE} ./status-task.sh optimist${INSTANCE_INDEX}

status-opt_txw:
	cd scripts && RELEASE=${RELEASE} ./status-service.sh opttxw${INSTANCE_INDEX}
	cd scripts && RELEASE=${RELEASE} ./status-task.sh opt_txw${INSTANCE_INDEX}

status-opt_bpw:
	cd scripts && RELEASE=${RELEASE} ./status-service.sh optbpw${INSTANCE_INDEX}
	cd scripts && RELEASE=${RELEASE} ./status-task.sh opt_bpw${INSTANCE_INDEX}

status-opt_baw:
	cd scripts && RELEASE=${RELEASE} ./status-service.sh optbaw${INSTANCE_INDEX}
	cd scripts && RELEASE=${RELEASE} ./status-task.sh opt_baw${INSTANCE_INDEX}

status-proposer:
	cd scripts && RELEASE=${RELEASE} ./status-service.sh proposer${INSTANCE_INDEX}
	cd scripts && RELEASE=${RELEASE} ./status-task.sh proposer${INSTANCE_INDEX}

status-challenger:
	cd scripts && RELEASE=${RELEASE} ./status-service.sh challenger${INSTANCE_INDEX}
	cd scripts && RELEASE=${RELEASE} ./status-task.sh challenger${INSTANCE_INDEX}

status-publisher:
	cd scripts && RELEASE=${RELEASE} ./status-service.sh publisher
	cd scripts && RELEASE=${RELEASE} ./status-task.sh publisher

status-dashboard:
	cd scripts && RELEASE=${RELEASE} ./status-service.sh dashboard
	cd scripts && RELEASE=${RELEASE} ./status-task.sh dashboard

status-client:
	cd scripts && RELEASE=${RELEASE} ./status-service.sh client${INSTANCE_INDEX} 
	cd scripts && RELEASE=${RELEASE} ./status-task.sh client${INSTANCE_INDEX}

status-client_txw:
	cd scripts && RELEASE=${RELEASE} ./status-service.sh clienttxw${INSTANCE_INDEX} 
	cd scripts && RELEASE=${RELEASE} ./status-task.sh client_txw${INSTANCE_INDEX}

status-client_auxw:
	cd scripts && RELEASE=${RELEASE} ./status-service.sh clientaux${INSTANCE_INDEX} 
	cd scripts && RELEASE=${RELEASE} ./status-task.sh client_aux${INSTANCE_INDEX}

status-client_bpw:
	cd scripts && RELEASE=${RELEASE} ./status-service.sh clientbpw${INSTANCE_INDEX} 
	cd scripts && RELEASE=${RELEASE} ./status-task.sh client_bpw${INSTANCE_INDEX}

status-worker:
	cd scripts && RELEASE=${RELEASE} ./status-service.sh worker${INSTANCE_INDEX} 
	cd scripts && RELEASE=${RELEASE} ./status-task.sh worker${INSTANCE_INDEX}

status-regulator:
	cd scripts && RELEASE=${RELEASE} ./status-service.sh regulator${INSTANCE_INDEX} 
	cd scripts && RELEASE=${RELEASE} ./status-task.sh regulator${INSTANCE_INDEX}

status-regulator_auxw:
	cd scripts && RELEASE=${RELEASE} ./status-service.sh regaux${INSTANCE_INDEX} 
	cd scripts && RELEASE=${RELEASE} ./status-task.sh reg_aux${INSTANCE_INDEX}

status-regulator_bpw:
	cd scripts && RELEASE=${RELEASE} ./status-service.sh regbpw${INSTANCE_INDEX} 
	cd scripts && RELEASE=${RELEASE} ./status-task.sh reg_bpw${INSTANCE_INDEX}

status-geth:
	@if [ "${DEPLOYER_ETH_NETWORK}" = "staging" ]; then\
	  cd scripts && RELEASE=${RELEASE} ./status-service.sh geth; \
	  RELEASE=${RELEASE} ./status-task.sh geth; \
	else \
	  echo "Local Geth service is disabled"; \
    fi

# Exec into containers
exec-optimist:
	cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh optimist${INSTANCE_INDEX}Container

exec-opt_txw:
	cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh opt_txw${INSTANCE_INDEX}Container

exec-opt_bpw:
	cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh opt_bpw${INSTANCE_INDEX}Container

exec-opt_baw:
	cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh opt_baw${INSTANCE_INDEX}Container

exec-proposer:
	cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh proposer${INSTANCE_INDEX}Container

exec-challenger:
	cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh challenger${INSTANCE_INDEX}Container

exec-publisher:
	cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh publisherContainer

exec-dashboard:
	cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh dashboardContainer

exec-geth:
	@if [ "${DEPLOYER_ETH_NETWORK}" = "staging" ]; then\
	  cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh geth; \
	else \
	  echo "Local Geth service is disabled"; \
    fi

exec-worker:
	cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh circomWorker${INSTANCE_INDEX}Container

exec-client:
	cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh client${INSTANCE_INDEX}Container

exec-client_txw:
	cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh client_txw${INSTANCE_INDEX}Container

exec-client_auxw:
	cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh client_auxw${INSTANCE_INDEX}Container

exec-client_bpw:
	cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh client_bpw${INSTANCE_INDEX}Container

exec-regulator:
	cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh regulator${INSTANCE_INDEX}Container

exec-regulator_auxw:
	cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh reg_auxw${INSTANCE_INDEX}Container

exec-regulator_bpw:
	cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh reg_bpw${INSTANCE_INDEX}Container

build-image:
	echo "Building ${NIGHTFALL_IMAGE} git commit ${GIT_COMMIT} release: ${RELEASE}....";\
	cd nightfall_3 && docker build -f docker/$(word 2, $(subst -, ,$(NIGHTFALL_IMAGE))).Dockerfile .\
	    -t ${ECR_REPO}/${NIGHTFALL_IMAGE}:test-${GIT_COMMIT}\
	    -t ${ECR_REPO}/${NIGHTFALL_IMAGE}:${RELEASE};\

build-service-image:
	echo "Building ${NIGHTFALL_IMAGE} git commit ${GIT_COMMIT} release: ${RELEASE}....";\
	cd services/${SERVICE} && docker build -f $(word 2, $(subst -, ,$(NIGHTFALL_IMAGE))).Dockerfile .\
	    -t ${ECR_REPO}/${NIGHTFALL_IMAGE}:test-${GIT_COMMIT}\
	    -t ${ECR_REPO}/${NIGHTFALL_IMAGE}:${RELEASE};\

# Check if docker images are available locally. If not, build them
push-image:
	$(eval DOCKER_IMAGES=$(shell docker images | grep ${ERC_REPO}/${NIGHTFALL_IMAGE} | grep ${GIT_COMMIT}))
	@if [ -z "${DOCKER_IMAGES}" ]; then\
	    $(eval BUILD_IMAGE=$(word 2, $(subst -, ,$(NIGHTFALL_IMAGE)))) \
		make build-${BUILD_IMAGE};\
    fi
	echo "Pushing ${NIGHTFALL_IMAGE} git commit ${GIT_COMMIT} release: ${RELEASE}....";
	@docker push ${ECR_REPO}/${NIGHTFALL_IMAGE}:test-${GIT_COMMIT};
	@docker push ${ECR_REPO}/${NIGHTFALL_IMAGE}:${RELEASE};

# Login to AWS ECR
login-ecr:
	@aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_REPO}

# Download Nightfall repo
update-repo:
	@test -e "nightfall_3" || git clone git@github.com:${NIGHTFALL_REPO}.git nightfall_3
	cd nightfall_3 && git stash
	@if [ "${NIGHTFALL_BRANCH}" ]; then\
       	cd nightfall_3 && git fetch --all && git checkout master && git pull && git checkout ${NIGHTFALL_BRANCH}; \
    fi
	cd nightfall_3 && npm i
	cd nightfall_3/cli && npm i

# Check EFS is correctly mounted.
check-efs:
	cd scripts && RELEASE=${RELEASE} ./create-efs-mount-target.sh

# Check Secrets are available
check-secrets:
	cd scripts && RELEASE=${RELEASE} ./check-secrets.sh

# Mount efs
mount-efs:
	cd scripts && RELEASE=${RELEASE} ./mount-efs.sh

# Umount efs
umount-efs:
	cd scripts && RELEASE=${RELEASE} ./umount-efs.sh

# Deploy contracts
deploy-contracts:
	make stop-geth
	make stop-infra
	@if [ "${DEPLOYER_ETH_NETWORK}" = "staging" ]; then\
	  make start-geth; \
    fi
	@make start-db
	@make delete-db
	@make init-db
	@make mount-efs
	cd scripts && RELEASE=${RELEASE} ./launch-deployer.sh
	@make start-infra

# Deploy contracts
continue-deploy-contracts:
	@make umount-efs
	@make mount-efs
	cd scripts && RELEASE=${RELEASE} ./launch-deployer-simple.sh
	@make start-infra

# Upgrade contracts
upgrade-contracts:
	make stop-infra
	@make mount-efs
	cd scripts && RELEASE=${RELEASE} UPGRADE=true ./launch-deployer.sh
	@make start-infra

kill-deployer:
	tmux kill-session -t ${RELEASE}-deployer || true
	docker stop worker

# Check differences between current and prepared deployment
deploy-diff:
	make cdk-context
	cd scripts && RELEASE=${RELEASE} ./check-deployment-diff.sh

# Copy AWS context files when making infra
cdk-context:
	cp aws/contexts/cdk.context.${RELEASE}.json aws/cdk.context.json

# Run scenario diagnostics
diagnose:
	cd scripts && RELEASE=${RELEASE} ./diagnose-setup.sh

# Get configuration
get-config:
	cd scripts && RELEASE=${RELEASE} ./get-configuration.sh

# Copy tmp files to destination to check differences with PNF master
#  At some point, these changes will be incorporated to master
copy-files:
	cp test/user/transaction.mjs nightfall_3/cli/src
	cp test/proposer/proposer-command.mjs nightfall_3/cli/src
	cp test/client/client-command.mjs nightfall_3/cli/src
	cp -R test/contracts-cli nightfall_3/test
	cp test/deployer/fund-accounts.mjs nightfall_3/cli/src
	mkdir -p nightfall_3/test/ping-pong-single
	cp test/ping-pong/* nightfall_3/test/ping-pong-single
	@cp docker/client-docker-entrypoint.sh nightfall_3/nightfall-client/docker-entrypoint.sh
	@cp docker/optimist-docker-entrypoint.sh nightfall_3/nightfall-optimist/docker-entrypoint.sh
	@cp docker/deployer-docker-entrypoint.sh nightfall_3/nightfall-deployer/entrypoint.sh
	@cp docker/adversary.Dockerfile nightfall_3/docker
	@cp docker/lazy_client.Dockerfile nightfall_3/docker
	cp docker/worker.Dockerfile nightfall_3/docker/worker.Dockerfile
	cp docker/challenger.Dockerfile nightfall_3/docker
	cp docker/admin-docker-entrypoint.sh nightfall_3/nightfall-administrator/docker-entrypoint.sh
	cp docker/proposer-docker-entrypoint.sh nightfall_3/apps/proposer/docker-entrypoint.sh
	cp tmp/workers/debug.mjs nightfall_3/nightfall-optimist/src/routes/
	cp tmp/workers/transaction-submitted-app.mjs nightfall_3/nightfall-optimist/src/workers
	cp tmp/workers/transaction-submitted.mjs nightfall_3/nightfall-optimist/src/event-handlers/
	cp tmp/workers/database.mjs nightfall_3/nightfall-optimist/src/services/


# Clean containers
clean:
	cd scripts && RELEASE=${RELEASE} ./clean-containers.sh
