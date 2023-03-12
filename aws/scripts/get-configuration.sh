#! /bin/bash

#  Describes setup configuration

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> RELEASE=<xxx> ./get-configuration-sj
#   where AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are the AWS credentials
#   
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



# Deployer
echo "################ DEPLOYER ###############################"
echo "DEPLOYER_ETH_NETWORK............... ${DEPLOYER_ETH_NETWORK}"
echo "DEPLOY_MOCK_TOKENS................. ${DEPLOY_MOCK_TOKENS}"
echo "CHALLENGE_PERIOD_AMOUNT............ ${CHALLENGE_PERIOD_AMOUNT} ${CHALLENGE_PERIOD_UNIT}"
echo "DEPLOYER_ADDRESS................... ${DEPLOYER_ADDRESS}"
echo "STATE_GENESIS_BLOCK................ ${STATE_GENESIS_BLOCK}"
echo "USE_AWS_PRIVATE_KEY................ ${USE_AWS_PRIVATE_KEY}"
echo "TEST_ERC20_ADDRESS................. ${TEST_ERC20_ADDRESS}"
echo "MULTISIG_APPROVERS................. ${MULTISIG_APPROVERS}"
echo "MULTISIG_SIGNATURE_THRESHOLD....... ${MULTISIG_SIGNATURE_THRESHOLD}"

if [[ "${DEPLOYER_ETH_NETWORK}" == "staging"* ]]; then
  echo "WETH_TESTNET_RESTRICT.................. ${WETH_TESTNET_RESTRICT}"
  echo "MATIC_TESTNET_RESTRICT................. ${MATIC_TESTNET_RESTRICT}"
  echo "USDC_TESTNET_RESTRICT.................. ${USDC_TESTNET_RESTRICT}"
  echo "STMATIC_TESTNET_RESTRICT............... ${STMATIC_TESTNET_RESTRICT}"
fi
echo -e "\n"


# Web3
echo "################ WEB3 ###############################"
echo "GAS_DEPLOYER...................... ${GAS_DEPLOYER}"
echo "GAS_USER.......................... ${GAS_USER}"
echo "GAS_PROPOSER...................... ${GAS_PROPOSER}"
echo "GAS_PRICE......................... ${GAS_PRICE}"
echo "GAS_MULTIPLIER.................... ${GAS_MULTIPLIER}"
echo "GAS_ESTIMATE_ENDPOINT............. ${GAS_ESTIMATE_ENDPOINT}"
echo -e "\n"

# Optimist
echo "################ OPTIMIST ###############################"
echo "OPTIMIST_N...................... ${OPTIMIST_N}"
echo "CHALLENGER_N.................... ${CHALLENGER_N}"
echo "MAX_BLOCK_SIZE.................. ${MAX_BLOCK_SIZE}"
echo "OPTIMIST_IS_ADVERSARY........... ${OPTIMIST_IS_ADVERSARY}"
echo "FULL_VERIFICATION_SELF_BLOCKS... ${OPTIMIST_FULL_VERIFICATION_SELF_PROPOSED_BLOCKS}"
echo "OPTIMIST_TX_WORKER_N............ ${OPTIMIST_TX_WORKER_N}"
echo "PROPOSER_N...................... ${PROPOSER_N}"
echo "PROPOSER_CHANGE_SECOND.......... ${PROPOSER_TIMER_CHANGE_PROPOSER_SECOND}"
echo "PROPOSER_MAX_ROTATE_TIMES....... ${PROPOSER_MAX_ROATE_TIMES}"
echo "PROPOSER_MAX_BLOCK_PERIOD_MILIS. ${PROPOSER_MAX_BLOCK_PERIOD_MILIS}"
echo -e "\n"

# Dashboard
echo "################ DASHBOARD ###############################"
echo "DASHBOARD_ENABLE............................... ${DASHBOARD_ENABLE}"
echo "BROADCAST_ALARM................................ ${BROADCAST_ALARM}"
echo "DASHBOARD_POLLING_INTERVAL_SECONDS............. ${DASHBOARD_POLLING_INTERVAL_SECONDS}"
echo "FARGATE_CHECK_PERIOD_MIN....................... ${FARGATE_CHECK_PERIOD_MIN}"
echo "BLOCKCHAIN_CHECK_PERIOD_MIN.................... ${BLOCKCHAIN_CHECK_PERIOD_MIN}"
echo "DOCDB_CHECK_PERIOD_MIN......................... ${DOCDB_CHECK_PERIOD_MIN}"
echo "EFS_CHECK_PERIOD_MIN........................... ${EFS_CHECK_PERIOD_MIN}"
echo "DYNAMODB_CHECK_PERIOD_MIN...................... ${DYNAMODB_CHECK_PERIOD_MIN}"
echo "PUBLISHER_STATS_CHECK_PERIOD_MIN............... ${PUBLISHER_STATS_CHECK_PERIOD_MIN}"
echo "AWS_CLOWDWATCH_METRIC_PERIOD_MINUTES........... ${AWS_CLOWDWATCH_METRIC_PERIOD_MINUTES}"
echo "OPTIMIST_STATS_CHECK_PERIOD_MIN................ ${OPTIMIST_STATS_CHECK_PERIOD_MIN}"
echo -e "\n"

### ALARMS
echo "################ ALARMS ###############################"
echo "FARGATE_STATUS_COUNT_ALARM.................... ${FARGATE_STATUS_COUNT_ALARM}"
echo "EFS_STATUS_COUNT_ALARM........................ ${EFS_STATUS_COUNT_ALARM}"
echo "BLOCKCHAIN_BALANCE_COUNT_ALARM................ ${BLOCKCHAIN_BALANCE_COUNT_ALARM}"
echo "PROPOSER_BALANCE_THRESHOLD.................... ${PROPOSER_BALANCE_THRESHOLD}"
echo "CHALLENGER_BALANCE_THRESHOLD.................. ${CHALLENGER_BALANCE_THRESHOLD}"
echo "DOCDB_PENDINGTX_COUNT_ALARM................... ${DOCDB_PENDINGTX_COUNT_ALARM}"
echo "DOCDB_PENDINGBLOCK_COUNT_ALARM................ ${DOCDB_PENDINGBLOCK_COUNT_ALARM}"
echo "DOCDB_STATUS_COUNT_ALARM...................... ${DOCDB_STATUS_COUNT_ALARM}"
echo "DYNAMODB_DATASTATUS_COUNT_ALARM............... ${DYNAMODB_DATASTATUS_COUNT_ALARM}"
echo "DYNAMODB_WSSTATUS_COUNT_ALARM................. ${DYNAMODB_WSSTATUS_COUNT_ALARM}"
echo "DYNAMODB_WS_COUNT_ALARM....................... ${DYNAMODB_WS_COUNT_ALARM}"
echo "DYNAMODB_NBLOCKS_COUNT_ALARM.................. ${DYNAMODB_NBLOCKS_COUNT_ALARM}"
echo "PUBLISHER_STATS_STATUS_COUNT_ALARM............ ${PUBLISHER_STATS_STATUS_COUNT_ALARM}"
echo "OPTIMIST_STATS_STATUS_COUNT_ALARM............. ${OPTIMIST_STATS_STATUS_COUNT_ALARM}"
echo -e "\n"

# WAF rules
echo "################ WAF ###############################"
echo "WAF_RULE_IP_REPUTATION_LIST_ENABLE.............. ${WAF_RULE_IP_REPUTATION_LIST_ENABLE}"
echo "WAF_RULE_COMMON_RULSET_ENABLE................... ${WAF_RULE_COMMON_RULSET_ENABLE}"
echo "WAF_RULE_SQL_INJECTION_ENABLE................... ${WAF_RULE_SQL_INJECTION_ENABLE}"
echo "WAF_RULE_PHP_ENABLE............................. ${WAF_RULE_PHP_ENABLE}"
echo "WAF_RULE_LOCAL_FILE_INJECTION_ENABLE............ ${WAF_RULE_LOCAL_FILE_INJECTION_ENABLE}"
echo "WAF_RULE_RATE_LIMIT_ENABLE...................... ${WAF_RULE_RATE_LIMIT_ENABLE}"
echo -e "\n"
