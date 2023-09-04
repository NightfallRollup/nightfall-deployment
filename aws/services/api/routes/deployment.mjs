/**
Route for deployment
*/

import express from 'express';
import {
  createDeployment,
  createDeploymentContracts,
  startDeployment,
  deleteDeployment,
  createDeploymentCluster,
  deleteDeploymentCluster,
} from '../services/deployment.mjs';

const router = express.Router();

router.post('/', async (req, res, next) => {
  try {
    const env = await createDeployment(req.body);
    res.sendStatus(env.status);
  } catch (err) {
    res.json({ error: err.message });
    next(err);
  }
});

router.post('/contracts', async (req, res, next) => {
  try {
    const env = await createDeploymentContracts(req.body);
    res.sendStatus(env.status);
  } catch (err) {
    res.json({ error: err.message });
    next(err);
  }
});

router.post('/start', async (req, res, next) => {
  try {
    const env = await startDeployment(req.body);
    res.sendStatus(env.status);
  } catch (err) {
    res.json({ error: err.message });
    next(err);
  }
});

router.post('/cluster', async (req, res, next) => {
  try {
    const env = await createDeploymentCluster(req.body);
    res.sendStatus(env.status);
  } catch (err) {
    res.json({ error: err.message });
    next(err);
  }
});

router.delete('/cluster', async (req, res, next) => {
  try {
    const env = await deleteDeploymentCluster(req.body);
    res.sendStatus(env.status);
  } catch (err) {
    res.json({ error: err.message });
    next(err);
  }
});

router.delete('/:envName', async (req, res, next) => {
  try {
    const env = await deleteDeployment(req.params);
    res.status(env.status).send(env.body);
  } catch (err) {
    res.json({ error: err.message });
    next(err);
  }
});

export default router;
