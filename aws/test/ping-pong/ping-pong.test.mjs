import config from 'config';
import localTest from './index.mjs';

const environment = config.ENVIRONMENTS[process.env.ENVIRONMENT] || config.ENVIRONMENTS.localhost;

describe('Ping-pong tests', () => {
  const environment2 = { ...environment };
  const { CLIENT2_CHECK } = process.env;

  if (process.env.LAUNCH_LOCAL === '') {
    environment.clientApiUrl = `https://${process.env.CLIENT_SERVICE}.${process.env.DOMAIN_NAME}`;
    environment.clientApiTxUrl = `https://${process.env.CLIENT_TX_WORKER_SERVICE}.${process.env.DOMAIN_NAME}`;
    environment.clientApiBpUrl = `https://${process.env.CLIENT_BP_WORKER_SERVICE}.${process.env.DOMAIN_NAME}`;

    if (CLIENT2_CHECK !== '') {
      environment2.clientApiUrl = process.env.CLIENT2_HOST;
      environment2.clientApiTxUrl = process.env.CLIENT2_TX_WORKER_HOST;
      environment2.clientApiBpUrl = process.env.CLIENT2_BP_WORKER_HOST;
    } else {
      environment2.clientApiUrl = `https://${process.env.CLIENT_SERVICE}.${process.env.DOMAIN_NAME}`;
      environment2.clientApiTxUrl = `https://${process.env.CLIENT_TX_WORKER_SERVICE}.${process.env.DOMAIN_NAME}`;
      environment2.clientApiBpUrl = `https://${process.env.CLIENT_BP_WORKER_SERVICE}.${process.env.DOMAIN_NAME}`;
    }
  }

  const regulatorUrl2 = process.env.REGULATOR1_HOST;
  const regulatorBpUrl2 = process.env.REGULATOR1_BP_WORKER_HOST;
  const regulatorUrl1 =
    process.env.REGULATOR2_CHECK !== '' ? process.env.REGULATOR2_HOST : process.env.REGULATOR1_HOST;
  const regulatorBpUrl1 =
    process.env.REGULATOR2_CHECK !== ''
      ? process.env.REGULATOR2_BP_WORKER_HOST
      : process.env.REGULATOR1_BP_WORKER_HOST;
  it('Runs ping-pong tests', async () => {
    localTest(true, environment, regulatorUrl1, regulatorBpUrl1);
    await localTest(false, environment2, regulatorUrl2, regulatorBpUrl2);
  });
});
