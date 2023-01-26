/**
 * Will deploy into the current default CLI account.
 *
 * Deployment:
 * cdk deploy --all
 */

/* eslint-disable no-new */
const { App } = require('aws-cdk-lib');
const { ApplicationStack } = require('../lib/application/application-stack');
const { ScheduleStack } = require('../lib/application/schedule-stack');
const { DashboardStack } = require('../lib/application/dashboard-stack');
const { WAFStack } = require('../lib/application/waf-stack');
const options = require('../lib/application/options.js');

const app = new App();

// Use account details from default AWS CLI credentials:
const account = process.env.CDK_DEFAULT_ACCOUNT;
const region = process.env.CDK_DEFAULT_REGION;
const env = { account, region };
const { envAttr } = options;

// Create Scheduler Stack
const scheduleStack = new ScheduleStack(app, `${envAttr.name}-Schedule`, {
  description: 'Fargate Scheduler Stack',
  env,
  options,
});

const { ecsScheduleFnc } = scheduleStack;

// Create Application Load Balancer
const appStack = new ApplicationStack(app, `${envAttr.name}-Apps`, {
  description: `${envAttr.name} Application Stack`,
  env,
  options,
  ecsScheduleFnc,
});

const { services, albs } = appStack;

// Create wAF
/*
new WAFStack(app, `${envAttr.name}-WAF`, {
  description: `${envAttr.name} WAF Stack`,
  env,
  options,
  alb: albs[0]._alb, // External ALB
});
*/


// Create Dashboard
new DashboardStack(app, `${envAttr.name}-Dashboard`, {
  description: `${envAttr.name} Dashboard Stack`,
  env,
  options,
  services,
  albs,
});