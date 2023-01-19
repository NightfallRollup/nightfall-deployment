/**
Route for status.
*/
import express from 'express';
import { getStatus, getDetailedStatus, clearStatus } from '../services/status.mjs';

const router = express.Router();

router.get('/', async (req, res, next) => {
  try {
    const status = getStatus();
    res.json(status);
  } catch (err) {
    next(err);
  }
});

router.get('/details', async (req, res, next) => {
  try {
    const status = getDetailedStatus();
    res.json(status);
  } catch (err) {
    next(err);
  }
});

router.post('/reset', async (req, res) => {
  clearStatus();
  res.sendStatus(200);
});

export default router;
