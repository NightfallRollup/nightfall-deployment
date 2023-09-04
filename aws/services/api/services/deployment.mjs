/*
  Deployment service includes the deplyment of nightfall services and infrastructure to AWS. It includes the following:
  - Build and push container images
  - Deploy infrastructure (init dB, deploy services), including primary and auxiliary clusters
  - Compile and deploy contracts
  - Fund ETH accounts
*/
import { resetRunningProcesses, readEnvironment, checkEnvironment } from './environment.mjs';
import { apiCodes, envActions } from '../constants/constants.mjs';
import { launchCommand } from './launch-command.mjs';
import {
  createDeploymentClusterCmd,
  createDeploymentCmd,
  createDeploymentContractCmd,
  deleteDeploymentClusterCmd,
  deleteDeploymentCmd,
  startDeploymentCmd,
} from '../constants/commands.mjs';

//  Deployment creation:
// `cd ../../ && RELEASE=${envName} make COMMAND=fund BATCH_DEPLOY=y build-all push-all deploy-infra deploy-contracts fund-accounts`
export async function createDeployment(deploymentParams) {
  const envStatus = await checkEnvironment(deploymentParams, envActions.CREATE_DEPLOYMENT);
  if (envStatus.status !== apiCodes.OK) return { status: envStatus.status };

  const { envName = '' } = deploymentParams;

  launchCommand(createDeploymentCmd(envName), readEnvironment(envName), resetRunningProcesses);

  return { status: apiCodes.OK };
}

// Deploy contracts
// `cd ../../ && RELEASE=${envName} COMMAND=fund BATCH_DEPLOY=y make deploy-contracts fund-accounts`,
export async function createDeploymentContracts(deploymentParams) {
  const envStatus = await checkEnvironment(deploymentParams, envActions.DEPLOY_CONTRACTS);
  if (envStatus.status !== apiCodes.OK) return { status: envStatus.status };

  const { envName = '' } = deploymentParams;

  launchCommand(
    createDeploymentContractCmd(envName),
    readEnvironment(envName),
    resetRunningProcesses,
  );

  return { status: apiCodes.OK };
}

// Deploy and start infrastructure
// `cd ../../ && RELEASE=${envName} START_INFRA=y make deploy-infra`,
export async function startDeployment(deploymentParams) {
  const envStatus = await checkEnvironment(deploymentParams, envActions.START_DEPLOYMENT);
  if (envStatus.status !== apiCodes.OK) return { status: envStatus.status };

  const { envName = '' } = deploymentParams;

  launchCommand(startDeploymentCmd(envName), readEnvironment(envName), resetRunningProcesses);

  return { status: apiCodes.OK };
}

export async function deleteDeployment(deploymentParams) {
  const envStatus = await checkEnvironment(deploymentParams, envActions.DELETE_DEPLOYMENT);
  if (envStatus.status !== apiCodes.OK) return { status: envStatus.status };

  const { envName = '' } = deploymentParams;

  launchCommand(deleteDeploymentCmd(envName), readEnvironment(envName), resetRunningProcesses);

  return { status: apiCodes.OK };
}

export async function createDeploymentCluster(deploymentParams) {
  const envStatus = await checkEnvironment(deploymentParams, envActions.CREATE_CLUSTER);
  if (envStatus.status !== apiCodes.OK) return { status: envStatus.status };

  const { envName = '', clusterName = '' } = deploymentParams;
  const _clusterName = clusterName[0].toUpperCase() + clusterName.slice(1).toLowerCase();

  launchCommand(
    createDeploymentClusterCmd(envName, _clusterName),
    readEnvironment(envName),
    resetRunningProcesses,
  );

  return { status: apiCodes.OK };
}

export async function deleteDeploymentCluster(deploymentParams) {
  const envStatus = await checkEnvironment(deploymentParams, envActions.DELETE_CLUSTER);
  if (envStatus.status !== apiCodes.OK) return { status: envStatus.status };

  const { envName = '', clusterName = '' } = deploymentParams;
  const _clusterName = clusterName[0].toUpperCase() + clusterName.slice(1).toLowerCase();
  console.log('ERERE', envName, _clusterName);

  launchCommand(
    deleteDeploymentClusterCmd(envName, _clusterName),
    readEnvironment(envName),
    resetRunningProcesses,
  );

  return { status: apiCodes.OK };
}
