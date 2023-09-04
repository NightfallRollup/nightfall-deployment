const REGIONS = {
  FRANKFURT: 'eu-central-1',
  IRELAND: 'eu-west-1',
  LONDON: 'eu-west-2',
  NVIRGINIA: 'us-east-1',
  OHIO: 'us-east-2',
  DEFAULT: 'eu-central-1',
};

const envStatus = {
  SUCCESS: 'success',
  PENDING: 'pending',
  FAILED: 'failed,',
};
const envActions = {
  CREATE_ENVIRONMENT: 'create-environment',
  DELETE_ENVIRONMENT: 'delete-environment',
  CREATE_DEPLOYMENT: 'create-deployment',
  DELETE_DEPLOYMENT: 'delete-deployment',
  DEPLOY_CONTRACTS: 'deploy-contracts',
  START_DEPLOYMENT: 'start-deployment',
  DIAGNOSE: 'diagnose',
  CREATE_CLUSTER: 'create-cluster',
  DELETE_CLUSTER: 'delete-cluster',
  GET_URLS: 'get-urls',
};

const apiCodes = {
  OK: 200,
  NOT_FOUND: 404,
  INVALID: 405,
  DUPLICATED: 422,
  BUSY: 423,
};

const envFilesDefault = [
  'aws.copy.env',
  'aws.env',
  'cluster.env',
  'init-env.env',
  'secrets-ganache.env',
  'secrets.env',
  'template.env',
];

export { REGIONS, envStatus, envActions, apiCodes, envFilesDefault };
