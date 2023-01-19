import config from 'config';
import localTest from './index.mjs';

const environment = config.ENVIRONMENTS[process.env.ENVIRONMENT] || config.ENVIRONMENTS.localhost;

describe('Ping-pong tests', () => {
  const environment2 = { ...environment };
  if (process.env.LAUNCH_LOCAL === '') {
    environment.clientApiUrl = `https://${process.env.CLIENT_SERVICE}.${process.env.DOMAIN_NAME}`;
    environment2.clientApiUrl = `https://${process.env.CLIENT_SERVICE}2.${process.env.DOMAIN_NAME}`;
  }
  it('Runs ping-pong tests', async () => {
    localTest(true, environment);
    await localTest(false, environment2);
  });
});
