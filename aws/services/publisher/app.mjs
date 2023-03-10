import express from 'express';
import bodyParser from 'body-parser';
import cors from 'cors';
import fileUpload from 'express-fileupload';

const app = express();
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  next();
});

app.use(cors());
app.use(bodyParser.json({ limit: '2mb' }));
app.use(bodyParser.urlencoded({ limit: '2mb', extended: true }));
app.use(
  fileUpload({
    createParentPath: true,
  }),
);

var stats = {};

function setStats(updatedStats) {
  stats = {
    ...updatedStats,
    timestamp: new Date().toUTCString(),
  };
}

app.get('/healthcheck', (req, res) => {
  res.sendStatus(200);
});

app.get('/stats', (req, res) => {
  res.json(stats);
});

export { app, setStats };
