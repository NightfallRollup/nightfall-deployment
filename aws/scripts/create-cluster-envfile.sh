#! /bin/bash

#  Creates new AWS ClusterEnv file

#  Usage
#  AWS_ACCESS_KEY_ID=<xxxx> AWS_SECRET_ACCESS_KEY=<xxxxxxxxxx> ENV_NAME=<xxx>  REGION=<xxx>./create-cluster-envfile.sh
#   where AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are the AWS credentials


_CLUSTER=${CLUSTER}
if [ "${CLUSTER}" ]; then
  _CLUSTER="${CLUSTER^^}_"
fi

echo -e "_OPTIMIST_N=\${${_CLUSTER}OPTIMIST_N}" > ../env/cluster.env
echo -e "_OPTIMIST_TX_WORKER_N=\${${_CLUSTER}OPTIMIST_TX_WORKER_N}" >> ../env/cluster.env
echo -e "_OPTIMIST_HTTP_HOST=\${${_CLUSTER}OPTIMIST_HTTP_HOST}" >> ../env/cluster.env
echo -e "_OPTIMIST_TX_WORKER_HOST=\${${_CLUSTER}OPTIMIST_TX_WORKER_HOST}" >> ../env/cluster.env
echo -e "_OPTIMIST_BP_WORKER_HOST=\${${_CLUSTER}OPTIMIST_BP_WORKER_HOST}" >> ../env/cluster.env
echo -e "_OPTIMIST_BA_WORKER_HOST=\${${_CLUSTER}OPTIMIST_BA_WORKER_HOST}" >> ../env/cluster.env

echo -e "_PROPOSER_N=\${${_CLUSTER}PROPOSER_N}" >> ../env/cluster.env
echo -e "_PROPOSER_HOST=\${${_CLUSTER}PROPOSER_HOST}" >> ../env/cluster.env

echo -e "_CHALLENGER_N=\${${_CLUSTER}CHALLENGER_N}" >> ../env/cluster.env
echo -e "_CHALLENGER_HOST=\${${_CLUSTER}CHALLENGER_HOST}" >> ../env/cluster.env

echo -e "_PUBLISHER_ENABLE=\${${_CLUSTER}PUBLISHER_ENABLE}" >> ../env/cluster.env
echo -e "_PUBLISHER_HOST=\${${_CLUSTER}PUBLISHER_HOST}" >> ../env/cluster.env

echo -e "_DASHBOARD_ENABLE=\${${_CLUSTER}DASHBOARD_ENABLE}" >> ../env/cluster.env
echo -e "_DASHBOARD_HOST=\${${_CLUSTER}DASHBOARD_HOST}" >> ../env/cluster.env

echo -e "_CLIENT_N=\${${_CLUSTER}CLIENT_N}" >> ../env/cluster.env
echo -e "_CLIENT_AUX_WORKER_N=\${${_CLUSTER}CLIENT_AUX_WORKER_N}" >> ../env/cluster.env
echo -e "_CLIENT_TX_WORKER_N=\${${_CLUSTER}CLIENT_TX_WORKER_N}" >> ../env/cluster.env
echo -e "_CIRCOM_WORKER_N=\${${_CLUSTER}CIRCOM_WORKER_N}" >> ../env/cluster.env
echo -e "_CLIENT_HOST=\${${_CLUSTER}CLIENT_HOST}" >> ../env/cluster.env
echo -e "_CLIENT_AUX_WORKER_HOST=\${${_CLUSTER}CLIENT_AUX_WORKER_HOST}" >> ../env/cluster.env
echo -e "_CLIENT_BP_WORKER_HOST=\${${_CLUSTER}CLIENT_BP_WORKER_HOST}" >> ../env/cluster.env
echo -e "_CLIENT_TX_WORKER_HOST=\${${_CLUSTER}CLIENT_TX_WORKER_HOST}" >> ../env/cluster.env
echo -e "_CIRCOM_WORKER_HOST=\${${_CLUSTER}CIRCOM_WORKER_HOST}" >> ../env/cluster.env

echo -e "_REGULATOR_N=\${${_CLUSTER}REGULATOR_N}" >> ../env/cluster.env
echo -e "_REGULATOR_HOST=\${${_CLUSTER}REGULATOR_HOST}" >> ../env/cluster.env
echo -e "_REGULATOR_AUX_WORKER_N=\${${_CLUSTER}REGULATOR_AUX_WORKER_N}" >> ../env/cluster.env
echo -e "_REGULATOR_AUX_WORKER_HOST=\${${_CLUSTER}REGULATOR_AUX_WORKER_HOST}" >> ../env/cluster.env
echo -e "_REGULATOR_BP_WORKER_HOST=\${${_CLUSTER}REGULATOR_BP_WORKER_HOST}" >> ../env/cluster.env