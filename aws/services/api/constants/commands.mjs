

const createEnvironmentCmd = (envName,region) => process.env.CREATE_ENVIRONMENT_CMD ||
  `cd ../../scripts && ENV_NAME=${envName} REGION=${region} ./create-env.sh`;
const refreshUrlsCmd = (envName, jsonEnvFile) => process.env.REFRESH_URLS_CMD ||
  `cd ../../scripts && RELEASE=${envName} FILTER=HOST OUT_FILE=${jsonEnvFile} ./to-json.sh`;
const deleteEnvironmentCmd = (envName, region) => process.env.DELETE_ENVIRONMENT_CMD ||
  `cd ../../scripts && ENV_NAME=${envName} REGION=${region} ./destroy-env.sh`;
const createDeploymentCmd = (envName) => process.env.CREATE_DEPLOYMENT_CMD ||
  `cd ../../ && RELEASE=${envName} COMMAND=fund BATCH_DEPLOY=y make create-deployment`;
const createDeploymentContractCmd = (envName) => process.env.CREATE_DEPLOYMENT_CONTRACT_CMD ||
  `cd ../../ && RELEASE=${envName} COMMAND=fund BATCH_DEPLOY=y make contracts-and-fund`;
const startDeploymentCmd = (envName) => process.env.START_DEPLOYMENT_CMD ||
  `cd ../../ && RELEASE=${envName} START_INFRA=y make deploy-infra`;
const deleteDeploymentCmd = (envName) => process.env.DELETE_DEPLOYMENT_CMD ||
  `cd ../../ && RELEASE=${envName} FORCE_DESTROY=--force make destroy-infra`;
const createDeploymentClusterCmd = (envName, clusterName) => process.env.CREATE_DEPLOYMENT_CMD ||
 `cd ../../ && RELEASE=${envName} CLUSTER=${clusterName} START_INFRA=y make deploy-cluster`;
const  deleteDeploymentClusterCmd = (envName, clusterName) => process.env.DELETE_DEPLOYMENT_CLUSTER ||
 `cd ../../ && RELEASE=${envName} CLUSTER=${clusterName}  START_INFRA=y FORCE_DESTROY=--force make destroy-cluster`;



export {
    createEnvironmentCmd,
    refreshUrlsCmd,
    deleteEnvironmentCmd,
    createDeploymentCmd,
    createDeploymentContractCmd,
    startDeploymentCmd,
    deleteDeploymentCmd,
    createDeploymentClusterCmd,
    deleteDeploymentClusterCmd,
}