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
      environment2.clientApiUrl = `https://${process.env.CLIENT_SERVICE}2.${process.env.DOMAIN_NAME}`;
      environment2.clientApiTxUrl = `https://${process.env.CLIENT_TX_WORKER_SERVICE}2.${process.env.DOMAIN_NAME}`;
      environment2.clientApiBpUrl = `https://${process.env.CLIENT_BP_WORKER_SERVICE}2.${process.env.DOMAIN_NAME}`;
    } else {
      environment2.clientApiUrl = `https://${process.env.CLIENT_SERVICE}.${process.env.DOMAIN_NAME}`;
      environment2.clientApiTxUrl = `https://${process.env.CLIENT_TX_WORKER_SERVICE}.${process.env.DOMAIN_NAME}`;
      environment2.clientApiBpUrl = `https://${process.env.CLIENT_BP_WORKER_SERVICE}.${process.env.DOMAIN_NAME}`;
    }
  }
  it('Runs ping-pong tests', async () => {
    localTest(true, environment);
    await localTest(false, environment2);
  });
});
