/**
Route for environment
*/
import express from 'express';
import {
  createEnvironment,
  getEnvironment,
  deleteEnvironment,
  refreshEnvironments,
  getEnvironments,
} from '../services/environment.mjs';

const router = express.Router();

router.post('/', async (req, res, next) => {
  try {
    const env = await createEnvironment(req.body);
    res.sendStatus(env.status);
  } catch (err) {
    res.json({ error: err.message });
    next(err);
  }
});

router.post('/refresh', async (req, res, next) => {
  try {
    const env = await refreshEnvironments();
    res.sendStatus(env.status);
  } catch (err) {
    res.json({ error: err.message });
    next(err);
  }
});

router.get('/', async (req, res, next) => {
  try {
    const env = await getEnvironments();
    res.status(env.status).send(env.body);
  } catch (err) {
    res.json({ error: err.message });
    next(err);
  }
});

router.get('/:envName', async (req, res, next) => {
  try {
    const env = await getEnvironment(req.params);
    res.status(env.status).send(env.body);
  } catch (err) {
    res.json({ error: err.message });
    next(err);
  }
});

router.delete('/:envName', async (req, res, next) => {
  try {
    const env = await deleteEnvironment(req.params);
    res.status(env.status).send(env.body);
  } catch (err) {
    res.json({ error: err.message });
    next(err);
  }
});

export default router;
