/* eslint-disable no-new */
const { Stack, Duration } = require('aws-cdk-lib');
const { Dashboard, GraphWidget, Metric } = require('aws-cdk-lib').aws_cloudwatch;
const { getCircuitHashes } = require('./utils.js');

function newMetric(metricParams) {
  const metric = new Metric(metricParams);
  return metric;
}

function publisherErrorMetric(envName, attr) {
  const metrics = [];

  metrics.push(
    newMetric({
      metricName: 'ERROR_429',
      namespace: `Nightfall/${envName}`,
      statistic: 'maximum',
      label: 'Error 429 (Publisher)',
      period: Duration.minutes(attr.metricPeriodMinutes),
    }),
  );
  metrics.push(
    newMetric({
      metricName: 'ERROR_410',
      namespace: `Nightfall/${envName}`,
      statistic: 'maximum',
      label: 'Error 410 (Publisher)',
      period: Duration.minutes(attr.metricPeriodMinutes),
    }),
  );

  metrics.push(
    newMetric({
      metricName: 'ERROR_OTHER',
      namespace: `Nightfall/${envName}`,
      statistic: 'maximum',
      label: 'Error Other (Publisher)',
      period: Duration.minutes(attr.metricPeriodMinutes),
    }),
  );

  return metrics;
}

function optimistErrorMetric(envName, attr) {
  const metrics = [];
  metrics.push(
    newMetric({
      metricName: 'STATUS_STATS_ERROR',
      namespace: `Nightfall/${envName}`,
      statistic: 'maximum',
      label: 'Stats Read Failed',
      period: Duration.minutes(attr.metricPeriodMinutes),
    }),
  );
  metrics.push(
    newMetric({
      metricName: 'NBLOCKS_INVALID',
      namespace: `Nightfall/${envName}`,
      statistic: 'maximum',
      label: 'N Blocks Invalid',
      period: Duration.minutes(attr.metricPeriodMinutes),
    }),
  );
  metrics.push(
    newMetric({
      metricName: 'PROPOSER_WS_CLOSED',
      namespace: `Nightfall/${envName}`,
      statistic: 'maximum',
      label: 'Proposer Ws Closed',
      period: Duration.minutes(attr.metricPeriodMinutes),
    }),
  );
  metrics.push(
    newMetric({
      metricName: 'PROPOSER_WS_FAILED',
      namespace: `Nightfall/${envName}`,
      statistic: 'maximum',
      label: 'Proposer Ws Failed',
      period: Duration.minutes(attr.metricPeriodMinutes),
    }),
  );
  metrics.push(
    newMetric({
      metricName: 'PROPOSER_BLOCK_NOT_SENT',
      namespace: `Nightfall/${envName}`,
      statistic: 'maximum',
      label: 'Proposer Block Not Sent',
      period: Duration.minutes(attr.metricPeriodMinutes),
    }),
  );


  return metrics;
}

function walletMetric(envName, attr) {
  const metrics = [];
  metrics.push(
    newMetric({
      metricName: 'MAX_WALLETS',
      namespace: `Nightfall/${envName}`,
      statistic: 'maximum',
      label: 'Maximum N. Wallets (dynamoDB)',
      period: Duration.minutes(attr.metricPeriodMinutes),
    }),
  );
  metrics.push(
    newMetric({
      metricName: 'MIN_WALLETS',
      namespace: `Nightfall/${envName}`,
      statistic: 'minimum',
      label: 'Minimum N. Wallets (dynamoDB)',
      period: Duration.minutes(attr.metricPeriodMinutes),
    }),
  );
  metrics.push(
    newMetric({
      metricName: 'AVG_WALLETS',
      namespace: `Nightfall/${envName}`,
      statistic: 'average',
      label: 'Average N. Wallets (dynamoDB)',
      period: Duration.minutes(attr.metricPeriodMinutes),
    }),
  );
  metrics.push(
    newMetric({
      metricName: 'AVG_WALLETS_publisher',
      namespace: `Nightfall/${envName}`,
      statistic: 'average',
      label: 'Average N. Wallets (publisher)',
      period: Duration.minutes(attr.metricPeriodMinutes),
    }),
  );

  return metrics;
}
/*
  N transactions measured by docDb
  N blocks forecasted (N transactions/N transactions per block)
  N blocks measured by docDb
  N blocks measured by dynamoDb
  N blocks measured by publisher
*/
function nightfallMetric(envName, attr) {
  const metrics = [];

  const circuitHashes = getCircuitHashes(`../volumes/${envName}/proving_files/circuithash.txt`);
  metrics.push(
    newMetric({
      metricName: 'NTRANSACTIONS_docDB',
      namespace: `Nightfall/${envName}`,
      statistic: 'maximum',
      label: 'N. transactions (docDB)',
      period: Duration.minutes(attr.metricPeriodMinutes),
    }),
  );

  for (const txType of circuitHashes){
    metrics.push(
      newMetric({
        metricName: `NL2TX-${txType.hash}_docDB`,
        namespace: `Nightfall/${envName}`,
        statistic: 'maximum',
        label: `N. ${txType.name}  (docDB)`,
        period: Duration.minutes(attr.metricPeriodMinutes),
      }),
    );
  }

  metrics.push(
    newMetric({
      metricName: 'NPENDING_TRANSACTIONS_docDB',
      namespace: `Nightfall/${envName}`,
      statistic: 'maximum',
      label: 'N. Pending Transactions (docDB)',
      period: Duration.minutes(attr.metricPeriodMinutes),
    }),
  );

  metrics.push(
    newMetric({
      metricName: 'NBLOCKS_docDB',
      namespace: `Nightfall/${envName}`,
      statistic: 'maximum',
      label: 'N. Blocks (docDB)',
      period: Duration.minutes(attr.metricPeriodMinutes),
    }),
  );

  metrics.push(
    newMetric({
      metricName: 'NCHALLENGEDBLOCKS_docDB',
      namespace: `Nightfall/${envName}`,
      statistic: 'maximum',
      label: 'N. Challenged Blocks (docDB)',
      period: Duration.minutes(attr.metricPeriodMinutes),
    }),
  );


  metrics.push(
    newMetric({
      metricName: 'NBLOCKS_dynamoDB',
      namespace: `Nightfall/${envName}`,
      statistic: 'maximum',
      label: 'N. Blocks (dynamoDB)',
      period: Duration.minutes(attr.metricPeriodMinutes),
    }),
  );

  metrics.push(
    newMetric({
      metricName: 'NBLOCKS_publisher',
      namespace: `Nightfall/${envName}`,
      statistic: 'maximum',
      label: 'N. Blocks (publisher)',
    }),
  );

  return metrics;
}
function blockChainBalanceMetric(envName, blockchainAttr) {
  const balanceMetrics = [];

  balanceMetrics.push(
    newMetric({
      metricName: 'Balance-proposer',
      namespace: `Nightfall/${envName}`,
      statistic: 'average',
      label: 'proposer',
      period: Duration.minutes(blockchainAttr.metricPeriodMinutes),
    }),
  );

  balanceMetrics.push(
    newMetric({
      metricName: 'Balance-challenger',
      namespace: `Nightfall/${envName}`,
      statistic: 'average',
      label: 'challenger',
      period: Duration.minutes(blockchainAttr.metricPeriodMinutes),
    }),
  );

  balanceMetrics.push(
    newMetric({
      metricName: 'Balance-shield-ETH',
      namespace: `Nightfall/${envName}`,
      statistic: 'average',
      label: 'shield-ETH',
      period: Duration.minutes(blockchainAttr.metricPeriodMinutes),
    }),
  );
  const tokenNames = blockchainAttr.tokenNameList.split(',');
  for (let tokenIdx = 0; tokenIdx < tokenNames.length; tokenIdx++) {
    balanceMetrics.push(
      newMetric({
        metricName: `Balance-shield-${tokenNames[tokenIdx]}`,
        namespace: `Nightfall/${envName}`,
        statistic: 'average',
        label: `shield-${tokenNames[tokenIdx]}`,
        period: Duration.minutes(blockchainAttr.metricPeriodMinutes),
      }),
    );
  }

  return balanceMetrics;
}

class DashboardStack extends Stack {
  /**
   * Creates alams
   *
   * @param {cdk.Construct} scope
   * @param {string} id
   * @param {cdk.StackProps=} props
   */
  constructor(scope, id, props) {
    super(scope, id, props);

    const { services, albs, options } = props;
    const { envAttr, metricsAttr } = options;

    // dashboard
    const dashboard = new Dashboard(this, `${envAttr.name}-dashboard`, {});

    const ecsCPU = new GraphWidget({
      width: 6,
      title: `ECS CPU Utilization`,
      left: services.map(service => service.metricCpuUtilization()),
    });

    const ecsMemory = new GraphWidget({
      width: 6,
      title: `ECS Memory Utilization`,
      left: services.map(service => service.metricMemoryUtilization()),
    });

    const albConsumedLCUs = new GraphWidget({
      width: 6,
      title: 'ALB Consumed LCUs',
      left: albs.map(alb => alb._alb.metricConsumedLCUs()),
    });

    // Define Metrics
    const blockchainBalanceMetrics = blockChainBalanceMetric(envAttr.name, metricsAttr.blockchain);
    const blockchainBalanceWidget = new GraphWidget({
      width: 6,
      title: 'Balances',
      left: blockchainBalanceMetrics,
    });

    const nightfallMetrics = nightfallMetric(envAttr.name, metricsAttr.nightfall);
    const nightfallWidget = new GraphWidget({
      width: 6,
      title: 'Nightfall State',
      left: nightfallMetrics,
    });

    const walletMetrics = walletMetric(envAttr.name, metricsAttr.wallet);
    const walletWidget = new GraphWidget({
      width: 6,
      title: 'Wallets',
      left: walletMetrics,
    });

    const publisherErrorMetrics = publisherErrorMetric(envAttr.name, metricsAttr.publisherErrors);
    const publisherErrorWidget = new GraphWidget({
      width: 6,
      title: 'Publisher Errors',
      left: publisherErrorMetrics,
    });

    const optimistErrorMetrics = optimistErrorMetric(envAttr.name, metricsAttr.optimistErrors);
    const optimistErrorWidget = new GraphWidget({
      width: 6,
      title: 'Optimist Errors',
      left: optimistErrorMetrics,
    });

    dashboard.addWidgets(
      ecsCPU,
      ecsMemory,
      albConsumedLCUs,
      blockchainBalanceWidget,
      nightfallWidget,
      walletWidget,
      publisherErrorWidget,
      optimistErrorWidget,
    );
  }
}

module.exports = { DashboardStack };
