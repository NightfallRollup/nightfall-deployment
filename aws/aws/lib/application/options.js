const envAttr = {
  // REQUIRED: Deployment name
  name: process.env.ENVIRONMENT_NAME,
  account: process.env.ACCOUNT_ID,
  region: process.env.REGION,
};
const vpcAttr = {
  // REQUIRED. Network VPC
  customVpcId: process.env.VPC_ID,
  // REQUIRED. Application Private Subnet IDs
  appSubnetIds: [
    process.env.BACK1_SUBNET_ID,
    process.env.BACK2_SUBNET_ID,
    process.env.BACK3_SUBNET_ID,
  ],
};
const dnsAttr = {
  // REQUIRED: Route53 Zone must be in same Account.
  zoneName: process.env.DOMAIN_NAME,
  // REQUIRED: Route53 Zone hosted ID
  hostedZoneId: process.env.HOSTED_ZONE_ID,
  // Optional: Use existing certificate if supplied. Must be a wildcard, or match the hostname above.
  certificateArn: '',
};

const efsAttr = {
  efsId: process.env.EFS_ID,
  efsSgId: process.env.EFS_SG_ID,
};

const gethAppAttr = {
  // REQUIRED. Application/Task name
  name: 'geth',
  assignPublicIp: false,
  enable: process.env.DEPLOYER_ETH_NETWORK === 'staging',
  // Specify Container and container image information
  containerInfo: {
    portInfo: [
      {
        containerPort: Number(process.env.BLOCKCHAIN_PORT),
        hostPort: Number(process.env.BLOCKCHAIN_PORT),
        hostname: process.env.BLOCKCHAIN_SERVICE,
        healthcheck: {
          healthyHttpCodes: '200-499',
        },
        albType: process.env.BLOCKCHAIN_SERVICE_ALB,
      },
      {
        containerPort: Number(process.env.BLOCKCHAIN_RPC_PORT),
        hostPort: Number(process.env.BLOCKCHAIN_RPC_PORT),
        hostname: process.env.BLOCKCHAIN_RPC_SERVICE,
        healthcheck: {
          healthyHttpCodes: '200-499',
        },
        albType: process.env.BLOCKCHAIN_SERVICE_ALB,
      },
    ],
    environmentVars: {
      GANACHE_CHAIN_ID: process.env.GANACHE_CHAIN_ID,
    },
    command: [],
    repository: process.env.ECR_REPO,
    imageName: 'geth',
    imageTag: process.env.RELEASE,
  },
  memoryLimitMiB: 4096,
  cpu: 2048,
  // Optional: set a schedule to start/stop the Task. CRON expressions without seconds. Time in UTC.
  schedule: {},
};

const proposerAppAttr = {
  nInstances : process.env.PROPOSER_N,
  // REQUIRED. Application/Task name
  name: 'proposer',
  assignPublicIp: false,
  enable: true,
  // Specify Container and container image information
  containerInfo: {
    portInfo: [
      {
        containerPort: Number(process.env.PROPOSER_PORT),
        hostPort: Number(process.env.PROPOSER_PORT),
        // REQUIRED. Route 53 will add hostname.zoneName DNS
        hostname: process.env.PROPOSER_SERVICE,
        healthcheck: {
          path: '/healthcheck',
        },
        albType: process.env.PROPOSER_SERVICE_ALB,
      },
    ],
    environmentVars: {
      OPTIMIST_HOST: process.env.OPTIMIST_HOST,
      OPTIMIST_HTTP_HOST: process.env.OPTIMIST_HTTP_HOST,
      OPTIMIST_WS_PORT: process.env.OPTIMIST_WS_PORT,
      OPTIMIST_HTTP_PORT: process.env.OPTIMIST_HTTP_PORT,
      OPTIMIST_HTTP_URL: `https://${process.env.OPTIMIST_HTTP_HOST}`,
      OPTIMIST_WS_URL: `wss://${process.env.OPTIMIST_HOST}`,
      PROPOSER_PORT: process.env.PROPOSER_PORT,
      PROPOSER_HOST: process.env.PROPOSER_HOST,
      PROPOSER_URL: `https://${process.env.PROPOSER_HOST}`,
      BLOCKCHAIN_WS_HOST: process.env.BLOCKCHAIN_WS_HOST,
      BLOCKCHAIN_PORT: process.env.BLOCKCHAIN_PORT,
      LOG_LEVEL: process.env.PROPOSER_LOG_LEVEL,
      LOG_HTTP_PAYLOAD_ENABLED: process.env.PROPOSER_LOG_HTTP_PAYLOAD_ENABLED,
      LOG_HTTP_FULL_DATA: process.env.PROPOSER_LOG_HTTP_FULL_DATA,
      BLOCKCHAIN_URL: `wss://${process.env.BLOCKCHAIN_WS_HOST}${process.env.BLOCKCHAIN_PATH}`,
      GAS_MULTIPLIER: process.env.GAS_MULTIPLIER,
      GAS_PRICE: process.env.GAS_PRICE,
      GAS: process.env.GAS_PROPOSER,
      ENVIRONMENT: 'aws',
      BLOCKCHAIN_PATH: process.env.BLOCKCHAIN_PATH,
      TIMER_CHANGE_PROPOSER_SECOND: process.env.PROPOSER_TIMER_CHANGE_PROPOSER_SECOND,
      MAX_ROTATE_TIMES: process.env.PROPOSER_MAX_ROTATE_TIMES,
      GAS_ESTIMATE_ENDPOINT: process.env.GAS_ESTIMATE_ENDPOINT,
    },
    secretVars: [
      {
        envName: ['PROPOSER_KEY'],
        type: ['secureString'],
        parameterName: [
          `${process.env.BOOT_PROPOSER_KEY_PARAM}`,
          `${process.env.PROPOSER2_KEY_PARAM}`,
          `${process.env.PROPOSER3_KEY_PARAM}`,
          `${process.env.PROPOSER4_KEY_PARAM}`,
          `${process.env.PROPOSER5_KEY_PARAM}`,
          `${process.env.PROPOSER6_KEY_PARAM}`,
          `${process.env.PROPOSER7_KEY_PARAM}`,
          `${process.env.PROPOSER8_KEY_PARAM}`,
          `${process.env.PROPOSER9_KEY_PARAM}`,
          `${process.env.PROPOSER10_KEY_PARAM}`
        ],
      },
    ],
    command: [],
    repository: process.env.ECR_REPO,
    imageName: 'nightfall-proposer',
    imageTag: process.env.RELEASE,
  },
  memoryLimitMiB: 512,
  cpu: 256,
  // Optional: set a schedule to start/stop the Task. CRON expressions without seconds. Time in UTC.
  schedule: {
    downtime: {
      at: process.env.PROPOSER_DOWNTIME_AT,
      length: process.env.PROPOSER_DOWNTIME_LENGTH_MINUTES,
    },
  },
};

const challengerAppAttr = {
  nInstances : process.env.CHALLENGER_N,
  // REQUIRED. Application/Task name
  name: 'challenger',
  assignPublicIp: false,
  enable: true,
  // Specify Container and container image information
  containerInfo: {
    portInfo: [
      {
        containerPort: Number(process.env.CHALLENGER_PORT),
        hostPort: Number(process.env.CHALLENGER_PORT),
        // REQUIRED. Route 53 will add hostname.zoneName DNS
        hostname: process.env.CHALLENGER_SERVICE,
        healthcheck: {
          path: '/healthcheck',
        },
        albType: process.env.CHALLENGER_SERVICE_ALB,
      },
    ],
    environmentVars: {
      OPTIMIST_HOST: process.env.OPTIMIST_HOST,
      OPTIMIST_HTTP_HOST: process.env.OPTIMIST_HTTP_HOST,
      OPTIMIST_WS_PORT: process.env.OPTIMIST_WS_PORT,
      OPTIMIST_HTTP_PORT: process.env.OPTIMIST_HTTP_PORT,
      OPTIMIST_HTTP_URL: `https://${process.env.OPTIMIST_HTTP_HOST}`,
      OPTIMIST_WS_URL: `wss://${process.env.OPTIMIST_HOST}`,
      CHALLENGER_PORT: process.env.CHALLENGER_PORT,
      CHALLENGER_HOST: process.env.CHALLENGER_HOST,
      BLOCKCHAIN_WS_HOST: process.env.BLOCKCHAIN_WS_HOST,
      BLOCKCHAIN_PORT: process.env.BLOCKCHAIN_PORT,
      LOG_LEVEL: process.env.CHALLENGER_LOG_LEVEL,
      LOG_HTTP_PAYLOAD_ENABLED: process.env.CHALLENGER_LOG_HTTP_PAYLOAD_ENABLED,
      LOG_HTTP_FULL_DATA: process.env.CHALLENGER_LOG_HTTP_FULL_DATA,
      BLOCKCHAIN_PATH: process.env.BLOCKCHAIN_PATH,
      BLOCKCHAIN_URL: `wss://${process.env.BLOCKCHAIN_WS_HOST}${process.env.BLOCKCHAIN_PATH}`,
      GAS_PRICE: process.env.GAS_PRICE,
      GAS: process.env.GAS_PROPOSER,
      ENVIRONMENT: 'aws',
    },
    secretVars: [
      {
        envName: ['CHALLENGER_KEY'],
        type: ['secureString'],
        parameterName: [
          `${process.env.BOOT_CHALLENGER_KEY_PARAM}`,
          `${process.env.CHALLENGER2_KEY_PARAM}`,
          `${process.env.CHALLENGER3_KEY_PARAM}`,
          `${process.env.CHALLENGER4_KEY_PARAM}`,
          `${process.env.CHALLENGER5_KEY_PARAM}`,
          `${process.env.CHALLENGER6_KEY_PARAM}`,
          `${process.env.CHALLENGER7_KEY_PARAM}`,
          `${process.env.CHALLENGER8_KEY_PARAM}`,
          `${process.env.CHALLENGER9_KEY_PARAM}`,
          `${process.env.CHALLENGER10_KEY_PARAM}`,
        ],
      },
    ],
    command: [],
    repository: process.env.ECR_REPO,
    imageName: 'nightfall-challenger',
    imageTag: process.env.RELEASE,
  },
  memoryLimitMiB: 512,
  cpu: 256,
  // Optional: set a schedule to start/stop the Task. CRON expressions without seconds. Time in UTC.
  schedule: {
    downtime: {
      at: process.env.CHALLENGER_DOWNTIME_AT,
      length: process.env.CHALLENGER_DOWNTIME_LENGTH_MINUTES,
    },
  },
};

const optimistAppAttr = {
  nInstances : process.env.OPTIMIST_N,
  // REQUIRED. Application/Task name
  name: 'optimist', 
  assignPublicIp: false,
  enable: true,
  // Specify Container and container image information
  containerInfo: {
    portInfo: [
      {
        containerPort: Number(process.env.OPTIMIST_WS_PORT),
        hostPort: Number(process.env.OPTIMIST_WS_PORT),
        // REQUIRED. Route 53 will add hostname.zoneName DNS
        hostname: process.env.OPTIMIST_WS_SERVICE,
        healthcheck: {
          healthyHttpCodes: '200-499',
        },
        albType: process.env.OPTIMIST_WS_SERVICE_ALB,
      },
      {
        containerPort: Number(process.env.OPTIMIST_HTTP_PORT),
        hostPort: Number(process.env.OPTIMIST_HTTP_PORT),
        // REQUIRED. Route 53 will add hostname.zoneName DNS
        hostname: process.env.OPTIMIST_HTTP_SERVICE,
        healthcheck: {
          path: '/healthcheck',
        },
        albType: process.env.OPTIMIST_HTTP_SERVICE_ALB,
      },
    ],
    environmentVars: {
      WEBSOCKET_PORT: process.env.OPTIMIST_WS_PORT,
      BLOCKCHAIN_WS_HOST: process.env.BLOCKCHAIN_WS_HOST,
      BLOCKCHAIN_PORT: process.env.BLOCKCHAIN_PORT,
      MAX_BLOCK_SIZE: process.env.MAX_BLOCK_SIZE,
      HASH_TYPE: process.env.OPTIMIST_HASH_TYPE,
      LOG_LEVEL: process.env.OPTIMIST_LOG_LEVEL,
      LOG_HTTP_PAYLOAD_ENABLED: process.env.OPTIMIST_LOG_HTTP_PAYLOAD_ENABLED,
      LOG_HTTP_FULL_DATA: process.env.OPTIMIST_LOG_HTTP_FULL_DATA,
      IS_CHALLENGER: process.env.OPTIMIST_IS_CHALLENGER,
      AUTOSTART_RETRIES: process.env.OPTIMIST_AUTOSTART_RETRIES,
      MONGO_URL: process.env.MONGO_URL,
      BLOCKCHAIN_URL: `wss://${process.env.BLOCKCHAIN_WS_HOST}${process.env.BLOCKCHAIN_PATH}`,
      GAS_PRICE: process.env.GAS_PRICE,
      FROM_ADDRESS: process.env.DEPLOYER_ADDRESS,
      ENVIRONMENT: 'aws',
      PROPOSER_MAX_BLOCK_PERIOD_MILIS: process.env.PROPOSER_MAX_BLOCK_PERIOD_MILIS,
      OPTIMIST_DB: process.env.OPTIMIST_DB,
      OPTIMIST_ADVERSARY_BAD_BLOCK_GENERATION_PERIOD: process.env.OPTIMIST_ADVERSARY_BAD_BLOCK_GENERATION_PERIOD,
      OPTIMIST_ADVERSARY_BAD_BLOCK_SEQUENCE: process.env.OPTIMIST_ADVERSARY_BAD_BLOCK_SEQUENCE,
      OPTIMIST_ADVERSARY_CONTROLLER_ENABLED: process.env.OPTIMIST_ADVERSARY_CONTROLLER_ENABLED,
    },
    secretVars: [
      {
        envName: ['MONGO_INITDB_ROOT_PASSWORD'],
        type: ['secureString'],
        parameterName: ['mongo_password'],
      },
      {
        envName: ['MONGO_INITDB_ROOT_USERNAME'],
        type: ['string'],
        parameterName: ['mongo_user'],
      },
    ],
    command: [],
    repository: process.env.ECR_REPO,
    imageNameIndex: process.env.OPTIMIST_IS_ADVERSARY,
    imageName: ['nightfall-optimist', 'nightfall-adversary'],
    imageTag: process.env.RELEASE,
  },
  // https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html
  memoryLimitMiB: 2048,
  cpu: 1024,
  //memoryLimitMiB: 8192,
  //cpu: 4096,
  // Optional: set a schedule to start/stop the Task. CRON expressions without seconds. Time in UTC.
  schedule: {},
  efsVolumes: [
    {
      path: '/build',
      volumeName: 'build',
      containerPath: '/app/build',
    },
  ],
};

const publisherAppAttr = {
  // REQUIRED. Application/Task name
  name: 'publisher',
  assignPublicIp: false,
  enable: true, 
  // Specify Container and container image information
  containerInfo: {
    portInfo: [
      {
        containerPort: Number(process.env.PUBLISHER_PORT),
        hostPort: Number(process.env.PUBLISHER_PORT),
        // REQUIRED. Route 53 will add hostname.zoneName DNS
        hostname: process.env.PUBLISHER_SERVICE,
        healthcheck: {
          path: '/healthcheck',
        },
        albType: process.env.PUBLISHER_SERVICE_ALB,
      },
    ],
    environmentVars: {
      OPTIMIST_DB: process.env.OPTIMIST_DB,
      MONGO_URL: process.env.MONGO_URL,
      CHECKPOINT_COLLECTION: process.env.CHECKPOINT_COLLECTION,
      PUBLISHER_POLLING_INTERVAL_SECONDS: process.env.PUBLISHER_POLLING_INTERVAL_SECONDS,
      PUBLISHER_MAX_WATCH_SECONDS: process.env.PUBLISHER_MAX_WATCH_SECONDS,
      PUBLISHER_PORT: process.env.PUBLISHER_PORT,
      DYNAMODB_DOCUMENTDB_TABLE: process.env.DYNAMODB_DOCUMENTDB_TABLE,
      DYNAMODB_WS_TABLE: process.env.DYNAMODB_WS_TABLE,
      API_HTTPS_SEND_ENDPOINT: process.env.API_HTTPS_SEND_ENDPOINT,
      SUBMITTED_BLOCKS_COLLECTION: process.env.SUBMITTED_BLOCKS_COLLECTION,
      TRANSACTIONS_COLLECTION: process.env.TRANSACTIONS_COLLECTION,
      TIMBER_COLLECTION: process.env.TIMBER_COLLECTION,
      REGION: process.env.REGION,
      DOMAIN_NAME: process.env.DOMAIN_NAME,
      ENVIRONMENT: 'aws',
      BLOCKCHAIN_PATH: process.env.BLOCKCHAIN_PATH,
    },
    secretVars: [
      {
        envName: ['MONGO_INITDB_ROOT_PASSWORD'],
        type: ['secureString'],
        parameterName: ['mongo_password'],
      },
      {
        envName: ['MONGO_INITDB_ROOT_USERNAME'],
        type: ['string'],
        parameterName: ['mongo_user'],
      },
    ],
    command: [],
    repository: process.env.ECR_REPO,
    imageName: 'nightfall-publisher',
    imageTag: process.env.RELEASE,
  },
  memoryLimitMiB: 4096,
  cpu: 1024,
  // Optional: set a schedule to start/stop the Task. CRON expressions without seconds. Time in UTC.
  schedule: {},
};

const dashboardAppAttr = {
  // REQUIRED. Application/Task name
  name: 'dashboard',
  assignPublicIp: false,
  enable: process.env.DASHBOARD_ENABLE === 'true',
  // Specify Container and container image information
  containerInfo: {
    portInfo: [
      {
        containerPort: Number(process.env.DASHBOARD_PORT),
        hostPort: Number(process.env.DASHBOARD_PORT),
        // REQUIRED. Route 53 will add hostname.zoneName DNS
        hostname: process.env.DASHBOARD_SERVICE,
        healthcheck: {
          path: '/healthcheck',
        },
        albType: process.env.DASHBOARD_SERVICE_ALB,
      },
    ],
    environmentVars: {
      DOMAIN_NAME: process.env.DOMAIN_NAME,
      ENVIRONMENT_NAME: process.env.ENVIRONMENT_NAME,
      BROADCAST_ALARM: process.env.BROADCAST_ALARM,
      DEPLOYER_ETH_NETWORK: process.env.DEPLOYER_ETH_NETWORK,
      PUBLISHER_URL: `https://${process.env.PUBLISHER_HOST}`,
      OPTIMIST_HTTP_URL: `https://${process.env.OPTIMIST_HTTP_HOST}`,
      MONGO_URL: process.env.MONGO_URL,
      BLOCKCHAIN_URL: `wss://${process.env.BLOCKCHAIN_WS_HOST}${process.env.BLOCKCHAIN_PATH}`,
      DYNAMODB_DOCUMENTDB_TABLE: process.env.DYNAMODB_DOCUMENTDB_TABLE,
      DYNAMODB_WS_TABLE: process.env.DYNAMODB_WS_TABLE,
      REGION: process.env.REGION,
      DASHBOARD_PORT: process.env.DASHBOARD_PORT,
      DASHBOARD_POLLING_INTERVAL_SECONDS: process.env.DASHBOARD_POLLING_INTERVAL_SECONDS,
      OPTIMIST_DB: process.env.OPTIMIST_DB,
      DASHBOARD_COLLECTION: process.env.DASHBOARD_COLLECTION,
      ALARMS_COLLECTION: process.env.ALARMS_COLLECTION,
      SUBMITTED_BLOCKS_COLLECTION: process.env.SUBMITTED_BLOCKS_COLLECTION,
      TRANSACTIONS_COLLECTION: process.env.TRANSACTIONS_COLLECTION,
      DASHBOARD_DB: process.env.DASHBOARD_DB,
      BOOT_PROPOSER_ADDRESS: process.env.BOOT_PROPOSER_ADDRESS,
      BOOT_CHALLENGER_ADDRESS: process.env.BOOT_CHALLENGER_ADDRESS,
      FARGATE_CHECK_PERIOD_MIN: process.env.FARGATE_CHECK_PERIOD_MIN,
      FARGATE_STATUS_COUNT_ALARM: process.env.FARGATE_STATUS_COUNT_ALARM,
      BLOCKCHAIN_CHECK_PERIOD_MIN: process.env.BLOCKCHAIN_CHECK_PERIOD_MIN,
      BLOCKCHAIN_BALANCE_COUNT_ALARM: process.env.BLOCKCHAIN_BALANCE_COUNT_ALARM,
      ERC20_TOKEN_ADDRESS_LIST: process.env.ERC20_TOKEN_ADDRESS_LIST,
      ERC20_TOKEN_NAME_LIST: process.env.ERC20_TOKEN_NAME_LIST,
      DOCDB_CHECK_PERIOD_MIN: process.env.DOCDB_CHECK_PERIOD_MIN,
      DOCDB_PENDINGTX_COUNT_ALARM: process.env.DOCDB_PENDINGTX_COUNT_ALARM,
      DOCDB_PENDINGBLOCK_COUNT_ALARM: process.env.DOCDB_PENDINGBLOCK_COUNT_ALARM,
      DOCDB_STATUS_COUNT_ALARM: process.env.DOCDB_STATUS_COUNT_ALARM,
      EFS_CHECK_PERIOD_MIN: process.env.EFS_CHECK_PERIOD_MIN,
      EFS_STATUS_COUNT_ALARM: process.env.EFS_STATUS_COUNT_ALARM,
      DYNAMODB_CHECK_PERIOD_MIN: process.env.DYNAMODB_CHECK_PERIOD_MIN,
      DYNAMODB_DATASTATUS_COUNT_ALARM: process.env.DYNAMODB_DATASTATUS_COUNT_ALARM,
      DYNAMODB_NBLOCKS_COUNT_ALARM: process.env.DYNAMODB_NBLOCKS_COUNT_ALARM,
      DYNAMODB_WSSTATUS_COUNT_ALARM: process.env.DYNAMODB_WSSTATUS_COUNT_ALARM,
      DYNAMODB_WS_COUNT_ALARM: process.env.DYNAMODB_WS_COUNT_ALARM,
      PROPOSER_BALANCE_THRESHOLD: process.env.PROPOSER_BALANCE_THRESHOLD,
      CHALLENGER_BALANCE_THRESHOLD: process.env.CHALLENGER_BALANCE_THRESHOLD,
      PUBLISHER_STATS_CHECK_PERIOD_MIN: process.env.PUBLISHER_STATS_CHECK_PERIOD_MIN,
      PUBLISHER_STATS_STATUS_COUNT_ALARM: process.env.PUBLISHER_STATS_STATUS_COUNT_ALARM,
      PROPOSER_MAX_BLOCK_PERIOD_MILIS: process.env.PROPOSER_MAX_BLOCK_PERIOD_MILIS,
      BLOCKCHAIN_SERVICE: process.env.BLOCKCHAIN_SERVICE,
      PROPOSER_SERVICE: process.env.PROPOSER_SERVICE,
      CHALLENGER_SERVICE: process.env.CHALLENGER_SERVICE,
      OPTIMIST_WS_SERVICE: process.env.OPTIMIST_WS_SERVICE,
      OPTIMIST_HTTP_SERVICE: process.env.OPTIMIST_HTTP_SERVICE,
      PUBLISHER_SERVICE: process.env.PUBLISHER_SERVICE,
      DASHBOARD_SERVICE: process.env.DASHBOARD_SERVICE,
      OPTIMIST_STATS_CHECK_PERIOD_MIN: process.env.OPTIMIST_STATS_CHECK_PERIOD_MIN,
      OPTIMIST_STATS_STATUS_COUNT_ALARM: process.env.OPTIMIST_STATS_STATUS_COUNT_ALARM,
      ENVIRONMENT: 'aws',
      S3_BUCKET_CLOUDFRONT: process.env.S3_BUCKET_CLOUDFRONT,
    },
    secretVars: [
      {
        envName: ['MONGO_INITDB_ROOT_PASSWORD'],
        type: ['secureString'],
        parameterName: ['mongo_password'],
      },
      {
        envName: ['MONGO_INITDB_ROOT_USERNAME'],
        type: ['string'],
        parameterName: ['mongo_user'],
      },
      {
        envName: ['SLACK_TOKEN'],
        type: ['secureString'],
        parameterName: ['Slack_Token'],
      },
    ],
    command: [],
    repository: process.env.ECR_REPO,
    imageName: 'nightfall-dashboard',
    imageTag: process.env.RELEASE,
  },
  memoryLimitMiB: 512,
  cpu: 256,
  // Optional: set a schedule to start/stop the Task. CRON expressions without seconds. Time in UTC.
  schedule: {},
};

const circomWorkerAppAttr = {
  nInstances: process.env.CLIENT_N,
  // REQUIRED. Application/Task name
  name: 'circomWorker',
  assignPublicIp: false,
  enable: true,
  // Specify Container and container image information
  containerInfo: {
    portInfo: [
      {
        containerPort: Number(process.env.CIRCOM_WORKER_PORT),
        hostPort: Number(process.env.CIRCOM_WORKER_PORT),
        // REQUIRED. Route 53 will add hostname.zoneName DNS
        hostname: process.env.CIRCOM_WORKER_SERVICE,
        healthcheck: {
          path: '/healthcheck',
        },
        albType: process.env.CIRCOM_WORKER_SERVICE_ALB,
      },
    ],
    environmentVars: {
      LOG_HTTP_PAYLOAD_ENABLED: process.env.CIRCOM_WORKER_LOG_HTTP_PAYLOAD_ENABLE,
      LOG_HTTP_FULL_DATA: process.env.CIRCOM_WORKER_LOG_HTTP_FULL_DATA,
    },
    secretVars: [
    ],
    command: [],
    repository: process.env.ECR_REPO,
    imageName: 'nightfall-worker',
    imageTag: process.env.RELEASE,
  },
  memoryLimitMiB: 2048,
  cpu: 1024,
  // Optional: set a schedule to start/stop the Task. CRON expressions without seconds. Time in UTC.
  schedule: {},
  efsVolumes: [
    {
      path: '/proving_files',
      volumeName: 'proving_files',
      containerPath: '/app/output',
    },
  ],
};

const clientAppAttr = {
  nInstances: process.env.CLIENT_N,
  // REQUIRED. Application/Task name
  name: 'client',
  assignPublicIp: process.env.CLIENT_SERVICE_ALB === 'external',
  enable: process.env.CLIENT_N !== "" && process.env.CLIENT_N !== '0',
  // Specify Container and container image information
  containerInfo: {
    portInfo: [
      {
        containerPort: Number(process.env.CLIENT_PORT),
        hostPort: Number(process.env.CLIENT_PORT),
        // REQUIRED. Route 53 will add hostname.zoneName DNS
        hostname: process.env.CLIENT_SERVICE,
        healthcheck: {
          path: '/healthcheck',
          unhealthyThresholdCount: 10,
          healthyThresholdCount: 2,
          healthyHttpCodes: '200-499',
        },
        albType: process.env.CLIENT_SERVICE_ALB,
      },
    ],
    environmentVars: {
      AUTOSTART_RETRIES: process.env.CLIENT_AUTOSTART_RETRIES,
      GAS: process.env.GAS_CLIENT,
      LOG_LEVEL: process.env.CLIENT_DEBUG,
      LOG_HTTP_PAYLOAD_ENABLED: process.env.CLIENT_LOG_HTTP_PAYLOAD_ENABLED,
      LOG_HTTP_FULL_DATA: process.env.CLIENT_LOG_HTTP_FULL_DATA,
      BLOCKCHAIN_WS_HOST: process.env.BLOCKCHAIN_WS_HOST,
      BLOCKCHAIN_URL: `wss://${process.env.BLOCKCHAIN_WS_HOST}${process.env.BLOCKCHAIN_PATH}`,
      BLOCKCHAIN_PORT: process.env.BLOCKCHAIN_PORT,
      MONGO_URL: process.env.MONGO_URL,
      CIRCOM_WORKER_HOST: process.env.CIRCOM_WORKER_HOST,
      GAS_PRICE: process.env.GAS_PRICE,
      STATE_GENESIS_BLOCK: process.env.STATE_GENESIS_BLOCK,
      ETH_ADDRESS: process.env.DEPLOYER_ADDRESS,
      DEPLOYER_ETH_NETWORK: process.env.DEPLOYER_ETH_NETWORK,
      PROTOCOL: process.env.CLIENT_PROTOCOL,
      COMMITMENTS_DB: process.env.COMMITMENTS_DB,
      ENVIRONMENT: 'aws',
      ENABLE_QUEUE: process.env.ENABLE_QUEUE,
    },
    secretVars: [
      {
        envName: ['MONGO_INITDB_ROOT_PASSWORD'],
        type: ['secureString'],
        parameterName: ['mongo_password'],
      },
      {
        envName: ['MONGO_INITDB_ROOT_USERNAME'],
        type: ['string'],
        parameterName: ['mongo_user'],
      },
    ],
    command: [],
    repository: process.env.ECR_REPO,
    imageNameIndex: process.env.CLIENT_IS_ADVERSARY,
    imageName: ['nightfall-client', 'nightfall-lazy_client'],
    imageTag: process.env.RELEASE,
  },
  memoryLimitMiB: 2048,
  cpu: 1024,
  // Optional: set a schedule to start/stop the Task. CRON expressions without seconds. Time in UTC.
  schedule: {},
  efsVolumes: [
    {
      path: '/build',
      volumeName: 'build',
      containerPath: '/app/build',
    },
  ],
};

const appsAttr = [
  gethAppAttr,
  optimistAppAttr,
  proposerAppAttr,
  publisherAppAttr,
  dashboardAppAttr,
  challengerAppAttr,
  circomWorkerAppAttr,
  clientAppAttr,
];

const edgeAttr = {
  hostname: process.env.BLOCKCHAIN_SERVICE,
  enable: process.env.DEPLOYER_ETH_NETWORK === 'staging_edge',
  connectTo: process.env.BLOCKCHAIN_SERVICE_ALB,
  hostPort: Number(process.env.BLOCKCHAIN_PORT),
  healthcheck: {
    healthyHttpCodes: '200-499',
  },
  deployInstance: true,
  properties: {
     name: 'edge',
     targetType: 'instance',
     instanceType: 't2.medium',
     instanceImage: '/aws/service/canonical/ubuntu/server/focal/stable/current/amd64/hvm/ebs-gp2/ami-id',
     userDataScript: 'edge-user-data.txt',
     volumeSize: 50,
     sgPorts: [22],
  },
};

const gethWsAttr = {
  hostname: process.env.BLOCKCHAIN_SERVICE,
  enable: !process.env.DEPLOYER_ETH_NETWORK.includes('staging'),
  connectTo: process.env.BLOCKCHAIN_SERVICE_ALB,
  hostPort: Number(process.env.BLOCKCHAIN_PORT),
  healthcheck: {
    healthyHttpCodes: '200-499',
  },
  ip:
    process.env.DEPLOYER_ETH_NETWORK === 'goerli'
      ? process.env.EC2_GETH_IP
      : process.env.EC2_GETH_IP_MAINNET,
};


const walletAttr = {
  hostname: process.env.WALLET_SERVICE,
  enable: process.env.WALLET_ENABLE === 'true',
  s3BucketArn: process.env.S3_BUCKET_CLOUDFRONT ? `arn:aws:s3:::${process.env.S3_BUCKET_CLOUDFRONT.split('//')[1]}` : '',
  connectTo: process.env.WALLET_SERVICE_ALB,
};

const ec2InstancesAttr = [gethWsAttr, edgeAttr, walletAttr];

const wafAttr = [
  // AWS IP Reputation list includes known malicious actors/bots and is regularly updated
  {
    name: 'AWS-AWSManagedRulesAmazonIpReputationList',
    enable: process.env.WAF_RULE_IP_REPUTATION_LIST_ENABLE,
    rule: {
      name: 'AWS-AWSManagedRulesAmazonIpReputationList',
      priority: 10,
      statement: {
        managedRuleGroupStatement: {
          vendorName: 'AWS',
          name: 'AWSManagedRulesAmazonIpReputationList',
        },
      },
      overrideAction: {
        none: {},
      },
      visibilityConfig: {
        sampledRequestsEnabled: true,
        cloudWatchMetricsEnabled: true,
        metricName: 'AWSManagedRulesAmazonIpReputationList',
      },
    },
  },
  // NOTE: It seems this rule doesn't let websocket through
  {
    name: 'AWS-AWSManagedRulesCommonRuleSet',
    enable: process.env.WAF_RULE_COMMON_RULSET_ENABLE,
    rule: {
      name: 'AWS-AWSManagedRulesCommonRuleSet',
      priority: 20,
      statement: {
        managedRuleGroupStatement: {
          vendorName: 'AWS',
          name: 'AWSManagedRulesCommonRuleSet',
          // Excluding generic RFI body rule for sns notifications
          // https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-list.html
          excludedRules: [{ name: 'GenericRFI_BODY' }, { name: 'SizeRestrictions_BODY' }],
        },
      },
      overrideAction: {
        none: {},
      },
      visibilityConfig: {
        sampledRequestsEnabled: true,
        cloudWatchMetricsEnabled: true,
        metricName: 'AWS-AWSManagedRulesCommonRuleSet',
      },
    },
  },
  // Common Rule Set aligns with major portions of OWASP Core Rule Set
  // Blocks common SQL Injection
  // Disabled to allow change streams notifications in publisher
  {
    name: 'AWSManagedRulesSQLiRuleSet',
    enable: process.env.WAF_RULE_SQL_INJECTION_ENABLE,
    rule: {
      name: 'AWSManagedRulesSQLiRuleSet',
      priority: 30,
      visibilityConfig: {
        sampledRequestsEnabled: true,
        cloudWatchMetricsEnabled: true,
        metricName: 'AWSManagedRulesSQLiRuleSet',
      },
      overrideAction: {
        none: {},
      },
      statement: {
        managedRuleGroupStatement: {
          vendorName: 'AWS',
          name: 'AWSManagedRulesSQLiRuleSet',
          excludedRules: [],
        },
      },
    },
  },
  // Blocks common PHP attacks such as using high risk variables and methods in the body or queries
  {
    name: 'AWSManagedRulePHP',
    enable: process.env.WAF_RULE_PHP_ENABLE,
    rule: {
      name: 'AWSManagedRulePHP',
      priority: 40,
      visibilityConfig: {
        sampledRequestsEnabled: true,
        cloudWatchMetricsEnabled: true,
        metricName: 'AWSManagedRulePHP',
      },
      overrideAction: {
        none: {},
      },
      statement: {
        managedRuleGroupStatement: {
          vendorName: 'AWS',
          name: 'AWSManagedRulesPHPRuleSet',
          excludedRules: [],
        },
      },
    },
  },
  // Blocks attacks targeting LFI(Local File Injection) for linux systems
  {
    name: 'AWSManagedRuleLinux',
    enable: process.env.WAF_RULE_LOCAL_FILE_INJECTION_ENABLE,
    rule: {
      name: 'AWSManagedRuleLinux',
      priority: 50,
      visibilityConfig: {
        sampledRequestsEnabled: true,
        cloudWatchMetricsEnabled: true,
        metricName: 'AWSManagedRuleLinux',
      },
      overrideAction: {
        none: {},
      },
      statement: {
        managedRuleGroupStatement: {
          vendorName: 'AWS',
          name: 'AWSManagedRulesLinuxRuleSet',
          excludedRules: [],
        },
      },
    },
  },
  // Rate limiting 500 packets every 5 minutes per IP
  {
    name: 'rate-limit',
    enable: process.env.WAF_RULE_RATE_LIMIT_ENABLE,
    rule: {
      name: 'rate-limit',
      priority: 60,
      visibilityConfig: {
        sampledRequestsEnabled: true,
        cloudWatchMetricsEnabled: true,
        metricName: 'rate-limit',
      },
      action: {
        block: {},
      },
      statement: {
        rateBasedStatement: {
          limit: 500,
          aggregateKeyType: 'IP',
        },
      },
    },
  },
];

const metricsAttr = {
  blockchain: {
    tokenAddressList: process.env.ERC20_TOKEN_ADDRESS_LIST,
    tokenNameList: process.env.ERC20_TOKEN_NAME_LIST,
    metricPeriodMinutes: process.env.AWS_CLOWDWATCH_METRIC_PERIOD_MINUTES,
  },
  wallet: {
    metricPeriodMinutes: process.env.AWS_CLOWDWATCH_METRIC_PERIOD_MINUTES,
  },
  nightfall: {
    metricPeriodMinutes: process.env.AWS_CLOWDWATCH_METRIC_PERIOD_MINUTES,
  },
  publisherErrors: {
    metricPeriodMinutes: process.env.AWS_CLOWDWATCH_METRIC_PERIOD_MINUTES,
  },
  optimistErrors: {
    metricPeriodMinutes: process.env.AWS_CLOWDWATCH_METRIC_PERIOD_MINUTES,
  }
};

module.exports = {
  envAttr,
  vpcAttr,
  dnsAttr,
  efsAttr,
  appsAttr,
  ec2InstancesAttr,
  wafAttr,
  metricsAttr,
};
