import { spawn } from 'child_process';
import { envStatus } from '../constants/constants.mjs';

export function launchCommand(mainCommand, environment, resetRunningProcesses) {
  const env = spawn(mainCommand, { shell: true });

  env.stdout.on('data', data => {
    //environment.logs += `${data}`;
    console.log('stdout:', `${data}`);
  });

  env.on('exit', function (code, signal) {
    console.log('DONE', code, signal);
    //environment.status = environment.stderr.includes('error')  || environment.error !== '' ? envStatus.FAILED : envStatus.SUCCESS;
    environment.status = signal || code ? envStatus.FAILED : envStatus.SUCCESS;
    resetRunningProcesses();
  });

  env.stderr.on('data', data => {
    //environment.stderr += newMsg;
    console.log('stderr:', `${data}`);
  });

  env.on('error', error => {
    environment.status = envStatus.FAILED;
    environment.error += `${error.message}`;
    console.log('error:', `${error.message}`);
  });
}
