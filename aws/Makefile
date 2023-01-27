#!/bin/bash

# Use: make release <VAR_NAME1=value1> <VAR_NAME2=value2> ....

##VERSIONS
# Specify git commit tag/branch. If unspecified, git commit will use current
NIGHTFALL_BRANCH=765f64df5e813cd24b7cf5f6392d2d4c8433d107
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

# Retrieve AWS Account ID
export ACCOUNT_ID=$(shell cat env/aws.env | sed  -n -e 's/^export ACCOUNT_ID=//p')

# RETRIEVE REGION from AWS config
export REGION_AWS=$(shell aws configure get region)
ifneq ($(REGION),$(REGION_AWS))
  $(error Undefined REGION)
endif

ECR_REPO=${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com
NIGHTFALL_REPO=nightfall_3

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

launch-admin:
	cd scripts && RELEASE=${RELEASE} ./launch-admin.sh

test-db:
	cd scripts && RELEASE=${RELEASE} COMMAND=${COMMAND} LAST_BLOCK=${LAST_BLOCK} ./test-db.sh

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
	cd scripts && DELETE_DB=y RELEASE=${RELEASE} CLIENT_COMMAND=mnemonic MNEMONIC="${MNEMONIC}" ./client-command.sh

fund-accounts:
	cp test/deployer/fund-accounts.mjs nightfall_3/cli/src
	cd scripts && RELEASE=${RELEASE} ./fund-accounts.sh

# Launch local ping pong test
test-ping_pong:
	mkdir -p nightfall_3/test/ping-pong-single
	cp test/ping-pong/* nightfall_3/test/ping-pong-single
	cd scripts && RELEASE=${RELEASE} TEST_LENGTH=${TEST_LENGTH} TEST=PING_PONG ./launch-test.sh

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
	docker stop client worker mongodb

ssh-edge:
	cd scripts && RELEASE=${RELEASE} INSTANCE_NAME=edge ./ssh-ec2.sh

lazy-optimist-enable:
	curl -X POST ${URL}/challenger/enable -H 'Content-Type: application/json' -d '{"enable":true}'

lazy-optimist-disable:
	curl -X POST ${URL}/challenger/enable -H 'Content-Type: application/json' -d '{"enable":false}'

deploy-wallet:
	if [ "${OVERWRITE_CODE}" = "y" ]; then\
		cp tmp/wallet/index.ts nightfall_3/wallet/src/static/supported-token-lists; \
		cp tmp/wallet/supported-tokens-edge.ts nightfall_3/wallet/src/static/supported-token-lists; \
		cp tmp/wallet/supported-tokens-local.ts nightfall_3/wallet/src/static/supported-token-lists; \
		cp tmp/wallet/supported-tokens-mainnet.ts nightfall_3/wallet/src/static/supported-token-lists; \
		cp tmp/wallet/supported-tokens-testnet.ts nightfall_3/wallet/src/static/supported-token-lists; \
		cp tmp/wallet/bridgeComponentIndex.jsx nightfall_3/wallet/src/components/BridgeComponent/index.jsx; \
		cp tmp/wallet/sendModal.tsx nightfall_3/wallet/src/components/Modals/sendModal.tsx; \
		cp tmp/wallet/TokenItemIndex.jsx nightfall_3/wallet/src/components/TokenItem/index.jsx; \
		cp tmp/wallet/TransactionsIndex.jsx nightfall_3/wallet/src/components/Transactions/index.jsx; \
		cp tmp/wallet/commitment-storage.js nightfall_3/wallet/src//nightfall-browser/services/commitment-storage.js; \
		cp tmp/wallet/TokenType.ts nightfall_3/wallet/src/static/supported-token-lists; \
		cp tmp/wallet/walletIndex.jsx nightfall_3/wallet/src/views/wallet/index.jsx; \
		cp tmp/wallet/local-storage.js nightfall_3/wallet/src/utils/lib/local-storage.js; \
		cp tmp/wallet/index.jsx nightfall_3/wallet/src/hooks/User/index.jsx; \
		cp tmp/wallet/database.js nightfall_3/wallet/src/nightfall-browser/services/database.js; \
		cp tmp/config/default.js nightfall_3/config/default.js; \
	fi
	cd scripts && RELEASE=${RELEASE} ./deploy-wallet.sh

deploy-wallet-local:
	if [ "${OVERWRITE_CODE}" = "y" ]; then\
		cp tmp/wallet/index.ts nightfall_3/wallet/src/static/supported-token-lists; \
		cp tmp/wallet/supported-tokens-edge.ts nightfall_3/wallet/src/static/supported-token-lists; \
		cp tmp/wallet/supported-tokens-local.ts nightfall_3/wallet/src/static/supported-token-lists; \
		cp tmp/wallet/supported-tokens-mainnet.ts nightfall_3/wallet/src/static/supported-token-lists; \
		cp tmp/wallet/supported-tokens-testnet.ts nightfall_3/wallet/src/static/supported-token-lists; \
		cp tmp/wallet/bridgeComponentIndex.jsx nightfall_3/wallet/src/components/BridgeComponent/index.jsx; \
		cp tmp/wallet/sendModal.tsx nightfall_3/wallet/src/components/Modals/sendModal.tsx; \
		cp tmp/wallet/TokenItemIndex.jsx nightfall_3/wallet/src/components/TokenItem/index.jsx; \
		cp tmp/wallet/TransactionsIndex.jsx nightfall_3/wallet/src/components/Transactions/index.jsx; \
		cp tmp/wallet/commitment-storage.js nightfall_3/wallet/src//nightfall-browser/services/commitment-storage.js; \
		cp tmp/wallet/TokenType.ts nightfall_3/wallet/src/static/supported-token-lists; \
		cp tmp/wallet/walletIndex.jsx nightfall_3/wallet/src/views/wallet/index.jsx; \
		cp tmp/wallet/local-storage.js nightfall_3/wallet/src/utils/lib/local-storage.js; \
		cp tmp/wallet/index.jsx nightfall_3/wallet/src/hooks/User/index.jsx; \
		cp tmp/wallet/database.js nightfall_3/wallet/src/nightfall-browser/services/database.js; \
		cp tmp/config/default.js nightfall_3/config/default.js; \
	fi
	cd scripts && RELEASE=${RELEASE} ./deploy-wallet-local.sh

# Build all images (client, optimist, proposer, challenger, publisher, liquidity_provider, adversary)
build-all:
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
	#@make build-liquidity_provider

# Push images to docker repo (client, optimist, proposer, challenger, publisher, liquidity_provider, adversary)
push-all:
	@make login-ecr
	$(eval GIT_COMMIT=$(shell git rev-parse HEAD))
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
	#@make push-image NIGHTFALL_IMAGE=nightfall-liquidity_provider GIT_COMMIT=${GIT_COMMIT}

# Build individual images
build-client:
	@cp docker/client-docker-entrypoint.sh nightfall_3/nightfall-client/docker-entrypoint.sh
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make build-image NIGHTFALL_IMAGE=nightfall-client GIT_COMMIT=${GIT_COMMIT}

build-optimist:
	@cp docker/optimist-docker-entrypoint.sh nightfall_3/nightfall-optimist/docker-entrypoint.sh
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make build-image NIGHTFALL_IMAGE=nightfall-optimist GIT_COMMIT=${GIT_COMMIT}

build-adversary:
	@cp docker/adversary.Dockerfile nightfall_3/docker
	@cp docker/optimist-docker-entrypoint.sh nightfall_3/nightfall-optimist/docker-entrypoint.sh
	@cd nightfall_3 && npm run build-adversary
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make build-image NIGHTFALL_IMAGE=nightfall-adversary GIT_COMMIT=${GIT_COMMIT}

build-lazy_client:
	@cp docker/client-docker-entrypoint.sh nightfall_3/nightfall-client/docker-entrypoint.sh
	@cp docker/lazy_client.Dockerfile nightfall_3/docker
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

build-liquidity_provider:
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make build-image NIGHTFALL_IMAGE=nightfall-liquidity_provider GIT_COMMIT=${GIT_COMMIT}

build-geth:
	cp nightfall_3/config/default.js services/geth/config
	cd services/geth && docker build -f geth.Dockerfile . -t ${ECR_REPO}/geth:${RELEASE}

build-circom:
	cd nightfall_3 && docker build -f docker/circom.Dockerfile . -t nightfall-circom:latest

# Push individual images to ECR
push-client:
	@make login-ecr
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make push-image NIGHTFALL_IMAGE=nightfall-client GIT_COMMIT=${GIT_COMMIT}

push-optimist:
	@make login-ecr
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make push-image NIGHTFALL_IMAGE=nightfall-optimist GIT_COMMIT=${GIT_COMMIT}

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

push-liquidity_provider:
	@make login-ecr
	$(eval GIT_COMMIT=$(shell cd nightfall_3 && git rev-parse HEAD))
	@make push-image NIGHTFALL_IMAGE=nightfall-liquidity_provider GIT_COMMIT=${GIT_COMMIT}

push-geth:
	@make login-ecr
	@docker push ${ECR_REPO}/geth:${RELEASE}

# Stop services
stop-infra:
	make stop-optimist
	make stop-proposer
	make stop-publisher
	make stop-dashboard
	make stop-challenger
	make stop-worker
	make stop-client
	#make stop-geth

stop-optimist:
	cd scripts && RELEASE=${RELEASE} ./restart-task.sh optimist${INSTANCE_INDEX}
	cd scripts && RELEASE=${RELEASE} ./stop-service.sh optimist${INSTANCE_INDEX}

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

# Start services
start-infra_all:
	make start-optimist
	make start-proposer
	make start-publisher
	make start-dashboard
	make start-challenger
	@if [ "${DEPLOYER_ETH_NETWORK}" = "staging" ]; then\
	   make start-geth; \
	else \
	  echo "Local Geth service is disabled"; \
    fi
	@if [ "${CLIENT_N}" ]; then\
	  make start-worker; \
	  make start-client; \
    else \
	  echo "Client service is disabled"; \
    fi

start-infra:
	cd scripts && RELEASE=${RELEASE} ./start-infra.sh

start-optimist:
	cd scripts && RELEASE=${RELEASE} ./start-service.sh optimist${INSTANCE_INDEX}

start-proposer:
	cd scripts && RELEASE=${RELEASE} ./start-service.sh proposer${INSTANCE_INDEX}

start-publisher:
	cd scripts && RELEASE=${RELEASE} ./start-service.sh publisher

start-dashboard:
	cd scripts && RELEASE=${RELEASE} ./start-service.sh dashboard

start-challenger:
	cd scripts && RELEASE=${RELEASE} ./start-service.sh challenger${INSTANCE_INDEX}

start-worker:
	cd scripts && RELEASE=${RELEASE} ./start-service.sh circom${INSTANCE_INDEX}

start-client:
	cd scripts && RELEASE=${RELEASE} ./start-service.sh client${INSTANCE_INDEX}

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

restart-worker:
	make stop-worker
	make start-worker

# Get task status
status-optimist:
	cd scripts && RELEASE=${RELEASE} ./status-service.sh optimist${INSTANCE_INDEX}
	cd scripts && RELEASE=${RELEASE} ./status-task.sh optimist${INSTANCE_INDEX}

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

exec-proposer:
	cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh proposer${INSTANCE_INDEX}Container

exec-challenger:
	cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh challenger${INSTANCE_INDEX}Container

exec-publisher:
	cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh publisherContainer

exec-dashboard:
	cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh dashboardContainer

exec-liquidity_provider:
	cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh liquidityContainer

exec-geth:
	@if [ "${DEPLOYER_ETH_NETWORK}" = "staging" ]; then\
	  cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh geth; \
	else \
	  echo "Local Geth service is disabled"; \
    fi

exec-worker:
	cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh circom${INSTANCE_INDEX}Container

exec-client:
	cd scripts && RELEASE=${RELEASE} COMMAND=/bin/bash ./execute-command.sh client${INSTANCE_INDEX}Container

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
	@test -e "${NIGHTFALL_REPO}" || git clone git@github.com:EYBlockchain/${NIGHTFALL_REPO}.git
	@cd ${NIGHTFALL_REPO} && git stash
	@if [ "${NIGHTFALL_BRANCH}" ]; then\
       	cd ${NIGHTFALL_REPO} && git fetch --all && git checkout master && git pull && git checkout ${NIGHTFALL_BRANCH}; \
    fi
	cd ${NIGHTFALL_REPO} && npm i
	cd ${NIGHTFALL_REPO}/cli && npm i

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


# Clean containers
clean:
	cd scripts && RELEASE=${RELEASE} ./clean-containers.sh
