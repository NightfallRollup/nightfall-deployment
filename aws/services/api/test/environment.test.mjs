/* eslint import/no-extraneous-dependencies: "off" */

import chai from 'chai';

const { expect } = chai;

import { launchCommand } from '../services/launch-command.mjs';
import { resetRunningProcesses } from '../services/environment.mjs';
import { envStatus } from '../constants/constants.mjs';

export const waitForTimeout = async timeoutInMs => {
  // eslint-disable-next-line no-undef
  await new Promise(resolve => setTimeout(resolve, timeoutInMs));
};

describe('LaunchCommand function', function () {
  it('Correct command returns SUCCESS', async function () {
    const environment = {};
    await launchCommand('ls -l', environment, resetRunningProcesses);
    await waitForTimeout(100);
    expect(environment.status).to.equal(envStatus.SUCCESS);
  });

  it('Incorrect command returns FAILED', async function () {
    const environment = {};
    await launchCommand('cat ./qwewewew', environment, resetRunningProcesses);
    await waitForTimeout(100);
    expect(environment.status).to.equal(envStatus.FAILED);
  });
});
