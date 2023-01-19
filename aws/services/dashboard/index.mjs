// REGION=eu-west-1 ENVIRONMENT_NAME=Staging \
// MONGO_INITDB_ROOT_PASSWORD_PARAM=mongo_password \
// MONGO_INITDB_ROOT_USERNAME_PARAM=mongo_user \
// node index.mjs

import * as alarms from './dashboard.mjs';

const { MONGO_URL } = process.env;

alarms.start(MONGO_URL);
