/*
  Environment service includes the provisioning of AWS infrastrcture require to deploy nightfall, including the following
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
*/

import fs from 'fs';
import AWS from 'aws-sdk';
import {
  REGIONS,
  envStatus,
  apiCodes,
  envActions,
  envFilesDefault,
} from '../constants/constants.mjs';
import { launchCommand } from './launch-command.mjs';
import {
  createEnvironmentCmd,
  deleteEnvironmentCmd,
  refreshUrlsCmd,
} from '../constants/commands.mjs';

// running Processes (busy) flag.
// TODO: Should probably use a mutex for this
var runningProcesses = false;

export function resetRunningProcesses() {
  runningProcesses = false;
}

// Environmanet object
const environment = {};

function newEnvironment(region, action, status, clusters) {
  return {
    action,
    status,
    region,
    clusters,
    logs: '',
    error: '',
    stderr: '',
  };
}
export function readEnvironment(envName) {
  return environment[envName];
}

function setEnvironment(envName, envData) {
  environment[envName] = { ...envData };
}

export async function checkEnvironment(envParams, action) {
  const { envName = '', clusterName = '' } = envParams;

  // check env name is correct
  if (typeof envName !== 'string' || envName === '') {
    return { status: apiCodes.INVALID };
  }

  // Retrieve available environments
  const environment = readEnvironment(envName);

  // check environment exists
  if (typeof environment === 'undefined') return { status: apiCodes.NOT_FOUND };

  if (environment.status === envStatus.PENDING) {
    return { status: apiCodes.BUSY };
  }

  if (action === envActions.CREATE_CLUSTER || action === envActions.DELETE_CLUSTER) {
    if (typeof clusterName !== 'string' || clusterName === '') {
      return { status: apiCodes.INVALID };
    }
  }
  const envClusters = environment.clusters;

  if (action === envActions.CREATE_CLUSTER) {
    if (envClusters.includes(clusterName)) {
      return { status: apiCodes.DUPLICATED };
    }
  }
  if (action === envActions.DELETE_CLUSTER) {
    if (!envClusters.includes(clusterName)) {
      return { status: apiCodes.NOT_FOUND };
    }
  }

  if (runningProcesses) {
    return { status: apiCodes.BUSY };
  }

  // create Deployment
  runningProcesses = true;
  setEnvironment(envName, {
    ...environment,
    action,
    status: envStatus.PENDING,
    logs: '',
    error: '',
    stderr: '',
  });

  return { status: apiCodes.OK };
}

export async function createEnvironment(environmentParams) {
  const { envName = '', region = REGIONS.DEFAULT } = environmentParams;

  // check name and region is correct
  if (
    typeof envName !== 'string' ||
    envName === '' ||
    typeof region !== 'string' ||
    !Object.values(REGIONS).includes(region)
  ) {
    return { status: apiCodes.INVALID };
  }

  if (runningProcesses) {
    return { status: apiCodes.BUSY };
  }
  if (envName in environment) {
    return { status: apiCodes.DUPLICATED };
  }

  // create Environment
  runningProcesses = true;
  environment[envName] = newEnvironment(
    region,
    envActions.CREATE_ENVIRONMENT,
    envStatus.PENDING,
    [],
  );

  launchCommand(createEnvironmentCmd(envName, region), environment[envName], resetRunningProcesses);

  return { status: apiCodes.OK };
}

async function refreshUrls(envName, jsonEnvFile) {
  launchCommand(
    refreshUrlsCmd(envName, jsonEnvFile),
    readEnvironment(envName),
    resetRunningProcesses,
  );
}

export async function getEnvironment(environmentParams) {
  const { envName = '' } = environmentParams;

  // check name and region is correct
  if (typeof envName !== 'string' || envName === '') {
    return { status: apiCodes.INVALID };
  }

  // create Environment
  if (envName in environment) {
    const jsonEnvFile = `/tmp/${envName}.json`;
    let jsonUrls = '';
    refreshUrls(envName, jsonEnvFile);

    if (fs.existsSync(jsonEnvFile)) {
      jsonUrls = JSON.parse(fs.readFileSync(jsonEnvFile, 'utf-8'));
      fs.unlinkSync(jsonEnvFile);
    }
    return {
      body: { envName, ...environment[envName], urls: jsonUrls },
      status: apiCodes.OK,
    };
  } else {
    return { status: apiCodes.NOT_FOUND, body: { envName } };
  }
}

export async function deleteEnvironment(environmentParams) {
  const { envName = '' } = environmentParams;

  // check name and region is correct
  if (typeof envName !== 'string' || envName === '') {
    return { status: apiCodes.INVALID };
  }

  if (runningProcesses) {
    return { status: apiCodes.BUSY };
  }

  // delete Environment
  if (!(envName in environment)) {
    return { status: apiCodes.NOT_FOUND };
  }

  // delete Environment
  runningProcesses = true;
  environment[envName] = newEnvironment(
    environment[envName].region,
    envActions.DELETE_ENVIRONMENT,
    envStatus.PENDING,
    [],
  );

  launchCommand(
    deleteEnvironmentCmd(envName, environment[envName].region),
    environment[envName],
    resetRunningProcesses,
  );

  return { status: apiCodes.OK };
}

export async function refreshEnvironments() {
  const regionPattern = 'export REGION=';
  const clusterPattern = 'export CURRENT_CLUSTERS=';
  // retrieve env files and regions
  const envFiles = [];
  fs.readdirSync('../../env').forEach(file => {
    if (!envFilesDefault.includes(file) && !file.startsWith('.')) {
      // read the file content
      const content = fs.readFileSync(`../../env/${file}`);
      var lines = content.toString().split('\n');
      let clusters = [];
      let region;
      for (const l of lines) {
        if (l.indexOf(regionPattern) > -1) {
          region = l.split(regionPattern)[1];
        }
        if (l.indexOf(clusterPattern) > -1) {
          clusters = l.split(clusterPattern)[1].split(',').slice(0, -1);
          continue;
        }
      }
      if (region) {
        envFiles.push({
          envName: file.slice(0, -4),
          region,
          clusters,
        });
      }
    }
  });

  // retrieve db
  AWS.config.getCredentials(function (err) {
    if (err) console.log(err.stack);
  });
  for (const env of envFiles) {
    const docDB = new AWS.DocDB({ region: env.region });
    docDB.describeDBInstances({}, function (err, data) {
      if (err) console.log('ERRR', err);
      else {
        for (const dbInstance of data.DBInstances) {
          const dbStatus = dbInstance.DBInstanceStatus;
          const id = dbInstance.DBInstanceIdentifier;
          console.log('XXXXXX', dbStatus, id);
          if (id.includes(env.envName) && dbStatus === 'available') {
            environment[env.envName] = {
              ...environment[env.envName],
              region: env.region,
              clusters: env.clusters,
              status: envStatus.SUCCESS,
            };
          }
        }
      }
    });
  }
  return { status: apiCodes.OK };
}

export async function getEnvironments() {
  const listedEnvs = [];
  for (const envName in environment) {
    listedEnvs.push({ envName, ...environment[envName] });
  }
  return {
    body: [...listedEnvs],
    status: apiCodes.OK,
  };
}
