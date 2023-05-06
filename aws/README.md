# Nightfall Deployment

This repository contains the necessary scripts to deploy Nightfall to AWS in a number of different blockchains.


![Nightfal Deployment](aws/lib/assets/Nightfall.png)

## Requirements
Installation has been tested with an Ubuntu 22.04.1 LTS machine

- docker (without sudo)
- [openvpn](https://openvpn.net/vpn-server-resources/installing-openvpn-access-server-on-a-linux-system/)
- [aws cli v2.4.16+](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [aws Session Manger plugin v1.2.295.0](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
- aws-cdk (npm install -g aws-cdk)
- [mongosh](https://docs.mongodb.com/mongodb-shell/install/)
- jq
- nfs-common
- node v16+
- tmux
- md5deep
- wget
- gh
- Valid AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY env variables from AWS credentials

## Installation
```cd aws && npm install```

## AWS Permissions
To create the necessary infrastructure on AWS, you will need a permissions to access multiple services. At this
time we don't have the complete list of permissions required.


## Configuration
Copy file `env/aws.copy.env` to `env/aws.env` and update the following parameters with your organization AWS credentials:
- ACCOUNT_ID : AWS Account ID
- S3_DEPLOYER_BUCKET : Name for S3 bucket to store contract artifacts. Bucket will be created
- S3_WALLET_BUCKET: Name for S3 bucket to store circuit artifact. Bucket will be created
- S3_CLOUDFRONT_BUCKET: Name for S3 bucket to deploy browser wallet. Bucket will be created
- HOSTED_ZONE_ID: AWS Route 52 Hosted Zone ID. Needs to exist in advance
- ETHERSCAN_API_KEY: API Key required to estimate gas
- GIT_TOKEN: git Personal Access Token that gives access to nf private repo as well as ssh keys management

```
# AWS ACCOUNT ID - ex: 941343234754
export ACCOUNT_ID=

# AWS S3 BUCKET when contract and artifacts will be stored - ex : nightfallv3-deployer
export S3_DEPLOYER_BUCKET=
# AWS S3 WALLET BUCKET to store artifacts required for browser wallet - ex: nightfallv3-wallet
export S3_WALLET_BUCKET=
# AWS S3 BUCKET to store browser wallet front end
export S3_CLOUDFRONT_BUCKET=

# AWS Route 53 Hosted zone ID - ex Z3473584103TYRTUME5TU
# Create your hosted zone here: https://us-east-1.console.aws.amazon.com/route53/v2/hostedzones#
export HOSTED_ZONE_ID=

# Configure your ETHERSCAN API KEY from [here](https://docs.etherscan.io/getting-started/viewing-api-usage-statistics)
# Ex - VR314WT78FTY76QE6IGRE45WNYUJN3458
export ETHERSCAN_API_KEY=

export GIT_TOKEN=ghp_LqIaPqIWERGed5345FGNgdg763dhfdgWg9
```

## Secrets
Private keys of the different entities in Nightfall are stored in AWS Parameter Store. `aws/paramstore/params.example.txt` contains an example
of the parameters that are to be stored in AWS paramstore. There are five types of parameters:
- Ethereum Private keys for deployer, challengers, proposers,  liquidity providers and users. You can add as many as necessary. - **SecretString**
- DocumentDB PWD - **SecretString**
- DocumentDB User - **String**
- Nightfall mnemonic for users - **SecretMnemonicString**
- Slack_Token - **SecretString** can be configured so that alerts are sent to a given Slack channel. If you don't know the value for this token, 
- Reserved_Env - **String** defines current owner for environment. Default owner is Available, meaning environment is not reserved
just put some random data, but this parameter must exist.

The file contains 3 columns:
1. Type of value : `SecretString` will be encrypted, `String` will not be encrypted, and `SecretMnemonicString` is a set of words separated by `_`. It will be encrypted on AWS
2. Value
3. Parameter name

Nightfall can be deployed in a private geth network (or ganache), or in public testnets. We are assuming that all environments deployed
will reuse the same keys for private geth networks (or ganache), and will define different keys for Ethereum testnet and mainnet.
To differentiate private geth (or ganache) from the rest, we append `_ganache` to the parameter name.

In order to configure secrets, copy `aws/paramstore/params.example.txt` to `aws/paramstore/params.txt` and update the values.

**NOTE** Private keys provided as an example are extracted from service deployed accounts using `geth`.
**NOTE** Last line of the file must be left empty. Else, the last parameter will not be added to AWS parameter store.
**NOTE** `mongo_password` is the password for DocumentDB. It needs to be longer than 8 characters. 

## Building an Environment
There is a set of scripts that automate the process of creating a new environment. An environment is the collection of AWS infrastructure required to
deploy Nightfall on AWS.

You can create any number of independent environments.  Recommended environment names include `production`, `testnet`, `staging`, `internal` and `preprod`. If you create a different one, you will need to update `Makefile` accordingly.

```
cd scripts
ENV_NAME=xxxx REGION=xxxx ./create-env.sh
```
`ENV_NAME` is the name of the new environment. If environment name starts by `tmp-`, new environment files
created will go unnoticed when doing a `git diff`. They are thought to be temporary environments. `Makefile` is 
prepared to automatically recognize tmp environments. If environment is named differently, then `Makefile` needs
to be updated to recognize new environment.
`REGION` is the AWS region where the environment will be created.

Some additional considerations:

`create-env.sh` generates :
- VPC with CIDR blocks 10.48.0.0/16
- 1 Internet GW 
- 3 Public Subnets (10.48.1.0/24, 10.48.2.0/24 and 10.48.3.0/24)
- 3 Private Subnets (10.48.21.0/24, 10.48.22.0/24 and 10.48.23.0/24)
- 4 routing tables (1 public with all public subnets, and one for each private subnet)
- 1 NAT in each public subnet, and associate it to one private subnet
- 1 EFS file system
- 1 documentDb cluster
- 1 VPN client endpoint with certificate in `./certificates/nightfall-<ENV_NAME>.ovpn`
- 2 S3 bucket
- 1 env file configuring the environment in `./env/<ENV_NAME>.env`
- 1 cdk file in `./aws/contexts/cdk.context.<ENV_NAME>.json`
- 4 lambda functions and 1 API Gateway
- fill AWS parameter store
- if WALLET_ENABLE is set to true, a cloudfront distribution will be created where browser wallet can be deployed

## Creating and Deleting Repositories
New environment may lack ECR repositories if they are created in new regions. To create the necessary repositories, launch:
```
cd scripts
REGION=<xxx> ./create-repos.sh
```

To delete Nightfall repositories from a region:
```
cd scripts
REGION=<xxx> ./destroy-repos.sh
```
## Destroying an environment
To tear down an environment:
```
cd scripts
ENV_NAME=<xxx> REGION=<xxx> ./destroy-env.sh
```

Additionally, every stage can be created/destroyed independently using the following scripts:
- create-vpc.sh
- create-cdk-context.sh
- create-efs.sh
- create-db.sh
- create-vpn.sh
- create-apigw.sh
- create-envfile.sh
- create-bucket.sh
- create-reserve.sh
- create-secrets.sh

To destroy environment:
- destroy-db.sh
- destroy-efs.sh
- destroy-vpn.sh
- destroy-vpc.sh
- destroy-cdk-context.sh
- destroy-apigw.sh
- destroy-bucket.sh
- SECRET_FILE=../aws/paramstore/params.txt ./destroy-secrets.sh
- destroy-reserve.sh
- destroy-envfile.sh

**NOTE** These scripts may fail for several reasons. If the creation fails, it is recommended to run the applicable
destroy script to delete all resources generated in the process. If the destroy script fails, try to run it again. If that still fails, you will need to destroy resources manually.

**NOTE** After creating an environment in a new region, and when deploying infrastructure using `RELEASE=xxx make deploy-infra` 
to this newly created environment, you may need to provision certain AWS resources. This process is called bootstrap. To bootstrap, type:
```
cdk bootstrap aws://<ACCOUNT_ID>/<REGION>
```
`<ACCOUNT_ID>` is the 12 number AWS account id
`<REGION>` is the region where the environment is deployed

## Building a Blockchain container using geth
Geth private network service is defined in `./services/geth`. To build the geth container:

1. Go to `./services/geth`
```
cd ./services/geth
```
2. Initialize `volumes` folder
```
./geth-standalone -i
```
3. Launch geth locally
```
./geth-standalone -s
```

4. Wait till DAG is created
```
./geth-standalone -l
```
When DAG is generated, the following is displayed
```
INFO [06-22|13:12:57.385] Generating DAG in progress               epoch=1 percentage=97 elapsed=14.045s
INFO [06-22|13:12:57.518] Generating DAG in progress               epoch=1 percentage=98 elapsed=14.178s
INFO [06-22|13:12:57.719] Generating DAG in progress               epoch=1 percentage=99 elapsed=14.379s
INFO [06-22|13:12:57.720] Generated ethash verification cache      epoch=1 elapsed=14.379s
INFO [06-22|13:12:58.571] Successfully sealed new block            number=9 sealhash=7f27ec..1257fa hash=7a0fa2..e94090 elapsed=3.955s
INFO [06-22|13:12:58.572] 🔨 mined potential block                  number=9 hash=7a0fa2..e94090
INFO [06-22|13:12:58.572] Commit new sealing work                  number=10 sealhash=531c9d..6ae951 uncles=0 txs=0 gas=0 fees=0 elapsed="106.007µs"
INFO [06-22|13:12:58.572] Commit new sealing work                  number=10 sealhash=531c9d..6ae951 uncles=0 txs=0 gas=0 fees=0 elapsed="702.404µs"
INFO [06-22|13:12:59.304] Successfully sealed new block            number=10 sealhash=531c9d..6ae951 hash=0c353f..dbb364 elapsed=732.404ms
INFO [06-22|13:12:59.304] 🔨 mined potential block                  number=10 hash=0c353f..dbb364
```

5. Stop geth
```
./geth-standalone -d
```

6. Change ownership
```
sudo chown -R ${USER} volumes
```

7. Build and push geth container to ERC
```
cd ../..
RELEASE=xxx make build-geth push-geth
```

## Spining EC2 instance to act as deployer
Optionally, one can create an EC2 instance to deploy Nightfall instead of doing it from local computer.
To spin the EC2 instance, follow this process:
1. Deploy EC2 instance
```
RELEASE=xxx make deploy-deployer
```

2. Initialize EC2 instance
EC2 instance requires some initialization:
- Environment files `aws.env` and `xxx.env` are copied
- AWS credentials
- SSH key generation in EC2 instance
- Add SSH from EC2 instance to github
```
RELEASE=xxx make init-deployer
```
**NOTE** This operation requires VPN.

3. ssh into EC2 instance
```
RELEASE=xxx make ssh-deployer
```
**NOTE** This operation requires VPN.
4. Destroy EC2 instance
```
RELEASE=xxx make destroy-deployer
```

**NOTE** This operation requires VPN.
## Deploying Nightfall to the newly created environment
1. Export AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY env variables from AWS credentials. You can also set them by typing
```
aws configure
```
2. Check env vars in `env\xxxxx.env` and set them to your preferred values, where `xxxx` is the new AWS created. 
More on env files [here](#aws-environment-configuration-files).

3. Configure Nightfall version to deploy. More on this [here](#makefile)
- Open `Makefile` and set `NIGHTFALL_BRANCH` to the Nightfall_3 branch/tag you want to install
4. Configure RELEASE with the name of the environment you want to deploy into

Different `RELEASE` are deploying in a separate deployment environment with the same name. 
Set RELEASE to one of this vale. To select the enviroment to deploy, append `RELEASE=<release value> make xxxx` to 
any target in the Makefile. In these document we assume that `RELEASE=<env name>`  is always appended to any selected `RELEASE=xxx make target` even though it is not shown explicitely.

5. Build conntainer images to AWS ECR repository
```
RELEASE=xxx make build-all
```
6. Build and push container images to AWS ECR repository
```
RELEASE=xxx make push-all
```
7. Start VPN
```
cd certificates
sudo openvpn nightfall-<RELEASE>.ovpn
```

8. Deploy infrastructure
First you need to deploy infrastructure and once this process is completed, you need to deploy contracts (if needed)
- To deploy AWS infrastructure only (including starting DocumentDb)
```
RELEASE=xxxx make deploy-infra
```

**NOTE** To deploy infrastructure, contracts, and to interact with most of AWS, you must have launched the VPN using the certificate in `certificate` folder. Note that you need to use the appropriate certificate depending on the environment you are working.
To start the Vpn, `sudo openpvn ../certificates/<certificate>`.

**NOTE** At the end of this step, all the services in ECS will be created. Some of the tasks will not be able to start. For example, `optimist` requires
that contracts are deployed, and this is not yet done. Some other services require `optimist` to have started.

**NOTE** At the end of this step, there may be an error message like the one below. Ignore it for now.

```
cd scripts && RELEASE=tmp-test ./start-infra.sh
Waiting for connection with web3-ws.tmp-test.polygon-nightfall.technology...
Connect to web3-ws.tmp-test.polygon-nightfall.technology...
Starting Optmist service...
Optimist service is running (and shouldnt). Running tasks : 1. Desired tasks: 1
Run make-stop optimist first
```

9. Deploy contracts
- To deploy contracts 
```
RELEASE=xxxx make deploy-contracts
```

During contract deployment, the `deployer` and `worker` containers are started. 

![Nightfall Deployer Containers](aws/lib/assets/deployment-containers.png)

A `tmux` session `xxx-deployer` is created showing the progress of the deployment. 

![Nightfall Deployer Tmux Session](aws/lib/assets/deployment-tmux.png)

Once the deployment has ended, you can kill containers and tmux session with
```
RELEASE=xxxx make kill-deployer
```

The `deployer bucket` should look like this:

![Nightfall Deployer S3 bucket](aws/lib/assets/deployer-bucket.png)

The `wallet bucket` should look like this:

![Nightfall Wallet S3 bucket](aws/lib/assets/wallet-bucket.png)

The ECS Cluster created should look like this:

![Nightfall ECS Cluster](aws/lib/assets/ecs-cluster.png)


Contracts and proving keys are generated in this step and stored in the corresponding shared efs volume.
When deployment is finished, contracts and proving keys are copied to an S3 bucket for future use.
The `EFS` drive is mounted on `${USER}/efs-xxx`. There should be two folders there:
- `build` with the deployed contracts artifacts
- `proving_files` with the deployed circuit artifacts

These files are also copied to S3 bucket referenced by env variable `S3_DEPLOYER_BUCKET-${ENV_NAME}`.

10. Check environment is correctly built
```
RELEASE=xxx make diagnose
```

11. Deploy a Nightfall client
```
RELEASE=xxx make launch-client
```

This command deploys a client on your local computer. The client is made up of 3 containers
- nightfall client
- nightfall worker
- mongodb

![Nightfall Client Containers](aws/lib/assets/client-docker.png)

This command also starts a tmux session showing queries to mongodb on the left, and client on the right.

![Nightfall Client Tmux](aws/lib/assets/client-tmux.png)

To connect to the client's mongo DB type `mongosh`

To kill a client tmux session and the deployed containers:
```
RELEASE=xxxx make kill-client
```

12. Fund accounts
Assuming that you used a geth private network to deploy Nightfall, there are a number of accounts created and prefunded on that blockchain.
You also need to fund them with MATIC to be able to pay transactions.
To fund blockchain accounts:

```
RELEASE=xxxx COMMAND=fund make fund-accounts
```

To verify funds in each account:
```
RELEASE=xxxx make fund-accounts
```

13. Launch some transactions
To launch initial transactions and propose the initial blocks
```
RELEASE=xxx make test-ping_pong
```

Ping pong test can be launched at any time to test that the deployment is working correctly.
While test is running, you can check client tmux session to see logs running.

14. Destroying environment
Once you're done with the environment and are ready to tear it up, the steps are:

- Destroy resources created
```
RELEASE=xxx make destroy-infra
```
You will be prompted to confirm this command. Type `y` to confirm.

- Destroy repos
```
cd scripts
REGION=<xxx> ./destroy-repos.sh
```
Only call this command if no other environment in the same AWS region is sharing those repositories.

- Destroy core infrastructure
```
cd scripts
ENV_NAME=xxx REGION=yyy ./destroy-env.sh
```
where `ENV_NAME` is the name of the environment to destroy and `REGION`is the AWS region where it was created.

## Other Commands

### Reserving a AWS environment
To reserve xxx AWS Environment use `RELEASE=xxx make reserve-env`.
To release xxx AWS Environment use `RELEASE=xxx make release-env`. 
Attempting to use a reserved AWS env by other user than the one that reserved it will trigger an error.
To bypass the reservation check use `RELEASE=xxx FORCE_ENV_BYPASS=y make yyy`. 

Reserving environments is useful if these environments are shared by multiple testers to prevent unwanted modifications.

### DocumentDb/MongoDb
Final environment uses a documentDb database compatible with MongoDb. We will refer to this database as MongoDb or DocumentDb indistinctively. 

To access Db you need to use the vpn or be inside the VPC. This command is used to test accesibility.
```
RELEASE=xxxx make connect-db
```

### Exec into containers
Deployment is done in AWS ECS, a container orchestrator from AWS. You can exec into containers by:
```
RELEASE=xxx make exec-<container-name>
```
where container name can be geth, proposer, optimist, challenger, publisher, dashboard,...

# Project structure
Nightfall deployment project structure looks as follows:

![Nightfal Deployment Project Structure](aws/lib/assets/nightfall-deployment-structure.png)

## aws
Nightfall is deployed on AWS using CDK. Folder `./aws` contains all the cdk stacks needed to deploy services to AWS.

### bin/deploy.js
`deploy.js` script launches all the cdk stacks.
- `ApplicationStack` can be found at ./aws/lib/application/applicaion-stack.js, launches and initializes ECS containers.
- `ScheduleStack` can be found at ./aws/lib/application/schedule-stack.js, manages turning on and off containers with a cron job.
- `DashboardStack` can be found at ./aws/lib/application/dashboard-stack.js, manages the Dashboard functionality from AWS CloudWatch. It allows to 
monitor different containers and variables.
- `WAFStack` can be found at ./aws/lib/application/waf-stack.js, manages the Web Application Firewall functionality. The rules configured include:

  - AWS IP Reputation list includes known malicious actors/bots and is regularly updated
  - Common Rule Set aligns with major portions of OWASP Core Rule Set -> This rule is disabled because it seems it doesn't let wss traffic go through.
  - Blocks common SQL Injection
  - Blocks common PHP attacks such as using high risk variables and methods in the body or queries
  - Blocks common PHP attacks such as using high risk variables and methods in the body or queries
  - Blocks attacks targeting LFI(Local File Injection) for linux systems 
  - Rate limiting 500 packets every 5 minutes per IP

### bin/keys
There is the possibility to spin EC2 instances. For example, when deploying Nightall on Polygon Edge as one of the alternatives,
a ssh key required to connect to the EC2 instance will be created here.

### bin/lib
Lib folder contains the different stack definitions. It also contains a file called `./aws/lib/options.js` with the configuration applied to
all services being run. In principle, you should not modify this file unless you understand what you want to do.

### bin/paramstore
This folder contains the definition of the secrets we want to upload to AWS paramstore in file `params.txt`. This file is not version controlled 
(its ignored in .gitignore)

### bin/scripts
This folder contains some user data commands to initialize the creation of EC2 instances. 

## certificates
This folder contains the VPN certificates for the created environments.

## docker
Folder contains some modifications to Nightfall dockerfiles and entrypoints required for services to run on AWS. These dockerfiles are automatically
copied when doing a `RELEASE=xxxx make build` command.

## env
Folder includes configuration files for each AWS environment.

### env/aws.env
Common configuration file for all AWS deployments. It includes general parameters such as `ACCOUNT_ID` and `HOSTED_ZONE_ID`.

### env/init-env.env
Description of basic AWS infrastructure structure.

### env/secrets-ganache.env
Secrets using when deploying to geth like blockchains.

### env/secrets.env
Secrets using when deploying to public blockchains.

### env/template.env
Template for the configuration files of the different AWS environments. After creating a new AWS environment with 
`ENV_NAME=xxxx REGION=xxxx ./create-env.sh`, a new configuration file with the environment name will be created.
This configuration file is a standard one, and user should be able to configure it according to the needs.

### AWS environment configuration files

## nightfall_3
Nighfall repo will be downloaded here.

## scripts
Folder containing set of utility scripts to manage Nightfal deployment.

## services
Folder contains auxiliary Nightfall services not part of the main repo. These services are only needed in real cloud deployments, not when launching
Nightfall on localhost.

## test
Folder containing some tests 

## tmp
Set temporry files. The files in this folder will substitute downloaded files from AWS repo. Ideally, this folder should be empty. But sometimes, we
required to do some modification to Nightfall repo, and while those changes were approved, we installed them here.

## volumes
Folder containing some cached artifacts from each deploymeny.

## Makefile

Nightfall deployment it controlled with a `Makefile`.
All commands follow a similar structure:
```
RELEASE=<xxxx> ENV_VAR1=<xxxx> ... make target1 target2...
```
`RELEASE` is the name of the environment where we want the command to take effect. It is a required parameter.
`ENV_VAR1`,`ENV_VAR2` : sometimes we may require to ented additional ENV Vars for the make command. This part is optional
`target1`, `target2`: set of make commands we want to execute. For example `RELEASE=xxxx make build-all push-all` will build all containers and push them to ECR.


There are some different parts in the `Makefile`

### NIGHTFALL BASELINE

```
##VERSIONS
# Specify git commit tag/branch. If unspecified, git commit will use current
NIGHTFALL_BRANCH=5f135c75ae1de441d23e4567a8a7fd86eca4263e
OVERWRITE_CODE=y
```
`NIGHTFALL_BRANCH` specifies the Nightfall repo (git@github.com:EYBlockchain/nightfall_3.git) git commit of git tag/branch that we want to deploy. 
Its only useful if we need to build containers from source. If not, containers will be downloaded from ERC.
`OVERWRITE_CODE` is a flag to allow code from `./tmp` folder to overwrite Nightfall repo.

### NIGHTFALL ENVIRONMENTS

```
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
		    ENVIRONMENT=${RELEASE_TMP}${_RELEASE_NAME_UPPER}
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
```

We are forcing the `makefile` to only accept `preprod`, `production`, `staging`, `testnet`, `internal` and `tmp-xxx` as valid environments.
Environments are passed with `RELEASE=<xxx>` option.  If a different `RELEASE` env var is configured, the `Makefile` will fail.

Additionally, there is a preacution mechanism in `production` environment. It prompts the user to ensure they want to use this environment.

### RESTRICTIONS

```
export USER_AWS=$(shell cat ~/.aws/credentials | sed  -n -e 's/^aws_access_key_id = //p')
export RESERVED_ENV=$(shell aws ssm get-parameter --name "/${ENVIRONMENT}/Reserved_Env" | jq '.Parameter.Value' | tr -d "\"" | tr -d " ") 
ifeq ($(FORCE_ENV_BYPASS),)
  ifneq ($(RESERVED_ENV),Available )
    ifneq ($(RESERVED_ENV),${USER_AWS} )
      $(error Environment ${RELEASE} used by ${RESERVED_ENV})
    endif
  endif
endif
```
AWS environments can be reserved to ensure two different tests do not collide. This reservation can be overidden by setting `FORCE_ENV_BYPASS=y`.


### COMMMANDS
The rest of the `Makefile` includes the set of actions available to execute from the `Makefile`.

# Fargate Tasks
There are different tasks deployed in Fargate:

## Geth
Private blockchain. Service description can be found in `./services/geth`.  The genesis file can be found 
in `./services/geth/config/geth/genesis.json`.  A number of accounts are created and funded with ETH by default. The created 
accounts and recommended use are described in `./services/geth/config/geth/test-keypairs.json`.  Geth service opens a http port at
8545 and a websocket port at 8546.

By default, geth container is not built and push when doing a `RELEASE=xxx make build-all push-all`. The reason is that this container is 
not expected to change frequently, so one can save some time by avoiding recurring building. If you need to build and push it, 
simply do `RELEASE=xxxx make build-geth push-geth`.

## Publisher
Publisher is an auxiliary task launched in fargate that monitors changes in `blocks` collection within `optimist_database` and
writes those updates to a DynamoDB table to serve browser wallet requests. A browser wallet is a Nightfall client that is not connected
to the blockchain, and uses the `publisher` service to obtain new blocks and synchronize the state.

Publisher service is define in `./services/publisher`.

## Dashboard

Dashboard is an auxiliary task launched in fargate that writes monitoring information to `documentDb` and maintains a AWS dashboard. Additionally,
this task also manages alarms.

Dashboard service is define in `./services/dashboard`.

Some metrics from different modules are collected and stored in documentDb under `dashboard` db. There are two collections
- `metrics` : includes some collected metrics
- `alarms` : include system alarms

To enable capture of `metrics` and `alarms` in a given setup, configure the appropriate `env` file and set `DASHBOARD_ENABLE` to true or false.

To get the latest alarm posted
```
RELEASE=<xxx> make get-alarms
```

To get the latest metrics stored
```
RELEASE=<xxx> make get-metrics
```

To get the latest 4 metrics stored
```
RELEASE=<xxx> LIMIT=4 make get-metrics
```

To flush alarms
```
RELEASE=<xxx> make flush-alarms
```

To flush metrics
```
RELEASE=<xxx> make flush-metrics
```

If you want to make some quick changes to dashboard module and test them quick, you can launch the container locally with
```
RELEASE=<xxx>  make test-dashboard
```
If the capture of metrics and alarms is enabled, alarms are sent automatically to `polygon-nightfall-alarms` Slack channel provided `BROADCAST_ALARM` is set in `env` file. 

Metrics are displayed in AWS dashboard at `https://eu-west-1.console.aws.amazon.com/cloudwatch/home?region=eu-west-1#dashboards`.
Select the appropriate dashboard.

Some of the options that can be configured in the `env` files:
- `FARGATE_CHECK_PERIOD_MIN` period to check if different fargate tasks are alive
- `BLOCKCHAIN_CHECK_PERIOD_MIN` period to check blockchain balances
- `DOCDB_CHECK_PERIOD_MIN` period to check documentDb
- `EFS_CHECK_PERIOD_MIN` period to check EFS
- `DYNAMODB_CHECK_PERIOD` period to check DynamoDB Tables
- `PUBLISHER_STATS_CHECK_PERIOD_MIN` period to check publisher stats
- `FARGATE_STATUS_COUNT_ALARM`  Number of consecutive failures in fargate status to accept before triggering an alarm
- `EFS_STATUS_COUNT_ALARM` Number of consecutive failures in EFS status to accept before triggering an alarm 
- `BLOCKCHAIN_BALANCE_COUNT_ALARM` Number of consecutive low balance reads before triggering an alarm
- `PROPOSER_BALANCE_THRESHOLD` Threshold below which proposer Eth balance is considered low
- `CHALLENGER_BALANCE_THRESHOLD` Threshold below which challenger Eth balance is considered low
- `DOCDB_NBLOCKS_COUNT_ALARM` Number of consecutive time where number of stored blocks in docDb doesn't match expected number
- `DOCDB_STATUS_COUNT_ALARM` Number of consecutive failures in accessing DocDb before triggering an alarm
- `DYNAMODB_DATASTATUS_COUNT_ALARM` Number of consecutive failures in accessing Dynamo Doc Table before triggereing an alarm
- `DYNAMODB_WSSTATUS_COUNT_ALARM` Number of consecutive failures in accessing Dynamo WS Table before triggering an alarm
- `DYNAMODB_WS_COUNT_ALARM` Number of connected wallets above which an alarm is triggered
- `DYNAMODB_NBLOCKS_COUNT_ALARM` Number of consecutive times where the number of blocks in DynamoDb table can differ from docDb number of blocks before triggering an alarm
- `PUBLISHER_STATS_STATUS_COUNT_ALARM` Number of consecutive failures when reading publidher stats before triggering an alarm
- `AWS_CLOWDWATCH_METRIC_PERIOD_MINUTES` Period to publish a new metric to AWS cloudwatch

## Optimist
Optimist can be configured as an adversarial optimist, which will generate incorrect blocks periodically. To enable optimist as an adversary set `OPTIMIST_IS_ADVERSARY` env variable in the corresponding env file.

```
export OPTIMIST_IS_ADVERSARY=false
```


## Proposer
Proposer task has several additional commands:

- To change to next proposer in the list
```
RELEASE=xxxx make change-proposer
```

- To deregister proposer
```
RELEASE=xxxx make deregister-proposer
```

In order to sucessfully send these commands, you will first need to have cloned `nightfall_3` repository.
```
RELEASE=xxxx make update-repo
```

You can configure which branch/tag to clone by configuring `NIGHTFALL_BRANCH` in Makefile.

## Challenger

## Administrator

## Client

## Circom worker

When environment is launched with `RELEASE=xxxx make deploy-infra`, tasks are created and started in random order. Internally, there are some
dependencies on task ordering. For example, `optimist` expects to detect blockchain up, and if not, it will wait until its available.
On the other hand, `proposer` will try to connect to `optimist` and after so many retries, it will restart.

There are some commands available to check task's status:

- To check task`s status
```
RELEASE=xxxx make status-<task-name>
```
where <task-name> can be geth, optimist, proposer,  publisher, dashboard,...

- To stop a task 
```
RELEASE=xxxx make stop-<task-name>
```
- To start a task 
```
RELEASE=xxxx make start-<task-name>
```

- To stop all tasks
```
RELEASE=xxxx make stop-infa
```
- To start all tasks (except for geth, that needs to be started with a separate command)
```
RELEASE=xxxx make start-infra
```


## Configuration
### Configuring Fargate Tasks
There are several applications defined that will be spun as services in ECS as independent Fargate tasks. The list of applications include:
 - geth : Currently, geth local network is deployed to test infrastructure.
 - optimist
 - proposer

 Every task contains some confguration options defined in [options.js](./aws/lib/application/options.js). The parameters are;
 - name: Required. Name of the application (i.e, proposer). It needs to be unique
 - assignPublicIp: Optional. Default value is false. Adds a public IP to the task. It should be left to `false`.
 - containerInfo{} : Contains different parameters to specify the container
    - portInfo: [{}] : Each container can have 0 or more ports enabled. If there is one or more ports, you need to define this field. 
       - containerPort: Port in container
       - hostPort: External port
       - hostname: Required. URL where service where be available
       - healthcheck{}: ALB checks that service is up an running by sending a GET / and expecting a 200 response. Health check can be configured
            with some customized options:
         - path: healthcheck enpoint (for example '/healthcheck')
         - port: If port where healthcheck is implemented is different to `hostPort`
         - healthyHttpCodes: If healthy http response is different to 200. This is a string that accepts an indidual reponse code (i.e '404'), several reponse codes ('200,404'), or a range of codes ('200-499')
         - interval: period in seconds when helthcheck is sent
         - timeout: in seconds
         - unhealthyThresholdCount: Number of consecutive unsucessful attempts before considering a service unhealth. When a service is considered
         unhealth, the ALB will tear it down and a new one will be scheduled.
       - priority: Leave a is.
       - albType: Choose between `external` or `internal` depending on whether or not services must be accessible from outside the VPC. Default is `external`
    - environmentVars{} : Set of environment vars to export to container. They must be string.
    - command: Container starting command if any (for example ['npm', 'start']).
    - repository: Required. Name of repository (for example '930411028516.dkr.ecr.eu-west-1.amazonaws.com').
    - imageName: Required. Name of image in repository (for example 'nightfall-proposer').
    - imageTag: Required. Name of image tag (for example 'latest')
 - cpu: Required. Number of vCPUs reserved for the task. See [here](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html) for
  possible codes, as not all cpu and memory combinations are allowed.
 - memoryLimitMiB: Required. Memory reserved for task in MB (for exampl 512),
  // Optional: set a schedule to start/stop the Task. CRON expressions without seconds. Time in UTC.
 - schedule{}: Required. We can add a schedule to tell the scheduler when tasks should be active. If object is left empty, task will be always on.
    - start: Optional. Starting time (for example '0 2 ? * MON-FRI *')
    - stop: Optiona. Ending time (for example '0 20 ? * * *')
 - efsVolumes[{}]: Optional. EFS volumes to use
     - path: Optional. Path to EFS volume (for exmaple '/build'). If path is not specified, default path is '\'.
     - volumeName: Required. Volume name (for example 'build')
     - containerPath: Required. Location where volume is mounted in container (for example '/app/build')

### Configuring Auxiliary Services
Nightfall deployment requires additional services other than the ones deployed in Fargate. These services are :
- Geth node
- Nightfall wallet
It is assument that these two services are launched separately, and they exist when we deploy nightfall infrastructure, but somehow we need to let nightfall infrastructure know how to access them.
To configure access to these auxiliary services we use the `gethAttr` and `walletAttr` defined in `options.js`.

 - hostname: Required. Defines the Url for the service name (i.e 'wallet')
 - connectTo: Required. Defines the type of connection. Possibilities are 'internal-alb', 'external-alb' or 'route-53'. Services connecting to 'route-53' option will only have a entry in route-53 to access the service, and no ALB will be used. Wallet will use this type of connection.
 - ip: Required for ALB connection. Defines the IP the ALB should connect to.
 - hostPort:  Required for ALB connection. Defines de port the ALB should connect to.
 - healthcheck{}: Required for ALB connection.
 - priority: Required for ALB connection. Leave as is.


## Configuring Ethereum Network
To configure between Staging (local Geth network), Goerli, staging_edge, or mainnet, you need to modify the corresponding `.env` file.

- To set Staging/Local Geth network
```
export DEPLOYER_ETH_NETWORK=staging
```
- To set Goerli
```
export DEPLOYER_ETH_NETWORK=goerli
```

- To set Mainnet
```
export DEPLOYER_ETH_NETWORK=mainnet
```

# Troubleshooting
- Ensure you have exported `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` from AWS credentials
- VPN is configured to disconnect after 30 minutes. If you see timeouts when trying to access AWS services, check that VPN connection is still running
- Deployment contracts and infrastrcuture require you are logged to the VPN.
- When doing a `RELEASE=xxxx make deploy-contracts` during `launch deployer` phase, a tmux session called `deployer` will be created.
You can log into this session by:
```
tmux a -t deployer
```
There will be two panes. The one on the left reports logs from `worker` container. The one on the
right shows logs from `deployer` container. 
To move between panes:
```
Crtl+b and Left/Right Arrow
```
To close tmux session:
```
Ctrl+b d
```
A tmux tutorial can be found [here](https://linuxize.com/post/getting-started-with-tmux/)

- Change streams need to be enabled for the complete `optimist_data` database even though its only needed in `blocks collection`.
If change streams is enabled in `blocks collection`, publisher doesn't receive any update. So, for now, and until we figure this
out, publisher needs to filter updates.

- WAF includes some predefined rules. One of this rules is OWASP. However, if this rule is enabled, websocket connections don't work.
Until this is understood, this rule will remain disabled. Also, SQL injection rules have been disabled because changeStream stops working when this rule is enabled. Solution may be to implement some type of IP whitelisting.

- When redeploying infrastructure with `RELEASE=xxxx make deploy-infra`, it sometimes fails depending on the changes done. It seems to be stuck
with publisher service. The only way out once this happens is to abort deployment, use AWS console to delete the publishing service, and delete stack from cloud formation page.

- Some commands require `sudo` and for the user to enter the password. It is therefore difficult to leave scripts running unattended as user may be prompted to enter the password.

- Configure RELEASE. Whenever launching a `make` command, ensure you set RELEASE to a valid deployment name (`internal`, `production` or `staging`)

- If you want to have makefile autocomplete, add this code to your .bashrc and type `source $HOME/.bashrc` for the autocomplete to start working

```
complete -W "\`grep -oE '^[a-zA-Z0-9_.-]+:([^=]|$)' ?akefile | sed 's/[^a-zA-Z0-9_.-]*$//'\`" make
```

- When deploying contracts, sometimes it just hungs. The problem is in EFS. You may need to do a `RELEASE=xxxx make umount-efs` for all RELEASES (`internal`, `staging` and `production`)



# Nightfall-administrator
Nightfall admin is a container that enables the modification of some `onlyOwner` parameters via a multi sig.

To launch container:
`RELEASE=xxx make launch-admin`

To stop container:
`docker stop nightfall-admin`

To get nonce:
```
wscat -c wss://<BLOCKCHAIN_WS_HOST>
 {"method":"eth_getTransactionCount","params":["0x8D97689C9818892B700e27F316cc3E41e17fBeb9", "latest"],"id":1,"jsonrpc":"2.0"}
```

To retrieve transaction from mongodb in expected array format
``` 
docker exec -it nightfall-admin bash
mongoexport -d administration -c signatures --jsonArray
```

# Wallet
## Deploying wallet 
Browser wallet can be deployed automatically by setting `WALLET_ENABLE=true` in the corresponding environment configuration file.

The steps are:
1. Enabe wallet deployment in configuration file
```
export WALLET_ENABLE=true
```
Also, ensure the required S3 buckets have been created. These S3 buckets are defined in the config file 
with the below varables, and created when environment was [created](#building-an-environment).

```
export S3_BUCKET_WALLET=
export S3_BUCKET_CLOUDFRONT=
```

2. Confirm changes in cdk stacks
```
RELEASE=xxx make deploy-diff
```

3. Deploy AWS infrastructure if changes in cdk stacks
```
RELEASE=xxx make deploy-infra
```

4. Update `ChainIdMapping`
Open `./wallet/src/common-files/utils/web3.js` and set `ChainIdMapping` appropriately
```
export const ChainIdMapping = {
  preprod: { chainId: '0x5', chainName: 'Goerli' },
  testnet: { chainId: '0x5', chainName: 'Goerli' },
  mainnet: { chainId: '0x1', chainName: 'Mainnet' },
  staging: { chainId: '0x5', chainName: 'Goerli' },
  internal: { chainId: '0x5', chainName: 'Goerli' },
  local: { chainId: '0x539', chainName: 'Ganache' }, // 1337
  production: { chainId: '0x1', chainName: 'Mainnet' },
};
```
Add the environment name as a new property, with the following fields:
- chainId: By default geth is deployed to 0x539.
- chainName: Set `Ganache` for private networks, `Mainnet` for public mainnet and any other thing for testnet public netwoks.

For more information, read [this](nightfall_3/wallet/README.md).

**NOTE** if your environment includes a `-` in the name like `tmp-test`, substitute `-` by `_` in the property name (like `tmp_test`).

```
export const ChainIdMapping = {
  preprod: { chainId: '0x5', chainName: 'Goerli' },
  tmp_test: { chainId: '0x539', chainName: 'Ganache' },
  testnet: { chainId: '0x5', chainName: 'Goerli' },
  mainnet: { chainId: '0x1', chainName: 'Mainnet' },
  staging: { chainId: '0x5', chainName: 'Goerli' },
  internal: { chainId: '0x5', chainName: 'Goerli' },
  local: { chainId: '0x539', chainName: 'Ganache' }, // 1337
  production: { chainId: '0x1', chainName: 'Mainnet' },
};
```

5. Deploy wallet
```
RELEASE=xxx make deploy-wallet
```

**NOTE**: Browser wallet uses `publisher` service to retrieve the state of Nightfall. Make sure that this
service is deployed if you are using the wallet.

**NOTE**: Command `make deploy-wallet` does step 4 automatically.

6. Connect to wallet
Wallet is deployed at https://${WALLET_HOST}


The first time you enter the wallet URL in the browser, you will be prompted to created a new Nightfall wallet by supplying a 12 word mnemonic. Just click `Generate Mnemonic` button, and then `Create Wallet` button.

7. Add new network to metamask

Blockchain URL is https://${BLOCKCHAIN_RPC_HOST}

## Deploy wallet in localhost
It is possible to deploy a wallet from localhost

he steps are:
1. Ensure required S3 buckets are created [created](#building-an-environment).

```
export S3_BUCKET_WALLET=
```

2. Confirm changes in cdk stacks
```
RELEASE=xxx make deploy-diff
```

3. Deploy AWS infrastructure if changes in cdk stacks
```
RELEASE=xxx make deploy-infra
```

4. Update `ChainIdMapping`
Open `./wallet/src/common-files/utils/web3.js` and set `ChainIdMapping` appropriately
```
export const ChainIdMapping = {
  preprod: { chainId: '0x5', chainName: 'Goerli' },
  testnet: { chainId: '0x5', chainName: 'Goerli' },
  mainnet: { chainId: '0x1', chainName: 'Mainnet' },
  staging: { chainId: '0x5', chainName: 'Goerli' },
  internal: { chainId: '0x5', chainName: 'Goerli' },
  local: { chainId: '0x539', chainName: 'Ganache' }, // 1337
  production: { chainId: '0x1', chainName: 'Mainnet' },
};
```
Add the environment name as a new property, with the following fields:
- chainId: By default geth is deployed to 0x539.
- chainName: Set `Ganache` for private networks, `Mainnet` for public mainnet and any other thing for testnet public netwoks.

For more information, read [this](nightfall_3/wallet/README.md).

**NOTE** if your environment includes a `-` in the name like `tmp-test`, substitute `-` by `_` in the property name (like `tmp_test`).

```
export const ChainIdMapping = {
  preprod: { chainId: '0x5', chainName: 'Goerli' },
  tmp_test: { chainId: '0x539', chainName: 'Ganache' },
  testnet: { chainId: '0x5', chainName: 'Goerli' },
  mainnet: { chainId: '0x1', chainName: 'Mainnet' },
  staging: { chainId: '0x5', chainName: 'Goerli' },
  internal: { chainId: '0x5', chainName: 'Goerli' },
  local: { chainId: '0x539', chainName: 'Ganache' }, // 1337
  production: { chainId: '0x1', chainName: 'Mainnet' },
};
```

5. Deploy wallet
```
RELEASE=xxx make deploy-wallet-local
```

**NOTE**: Browser wallet uses `publisher` service to retrieve the state of Nightfall. Make sure that this
service is deployed if you are using the wallet.

**NOTE**: Command `make deploy-wallet-local` does step 4 automatically.

6. Connect to wallet
Wallet is deployed at http://localhost:3000/nightfall


The first time you enter the wallet URL in the browser, you will be prompted to created a new Nightfall wallet by supplying a 12 word mnemonic. Just click `Generate Mnemonic` button, and then `Create Wallet` button.

7. Add new network to metamask

Blockchain URL is https://${BLOCKCHAIN_RPC_HOST}