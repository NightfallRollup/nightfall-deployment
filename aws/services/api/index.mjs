/* eslint no-shadow: "off" */

import express from 'express';
import swaggerUi from 'swagger-ui-express';
import YAML from 'yamljs';
import { setupHttpDefaults } from '@polygon-nightfall/common-files/utils/httputils.mjs';
import { deployment, environment } from './routes/index.mjs';
import { refreshEnvironments } from './services/environment.mjs';

const swaggerDocument = YAML.load('./api/openapi.yaml');
const app = express();

setupHttpDefaults(
  app,
  app => {
    app.use('/deployment', deployment);
    app.use('/environment', environment);
    app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument));
  },
  true,
  false,
);

refreshEnvironments();

app.listen(9000);

export default app;
