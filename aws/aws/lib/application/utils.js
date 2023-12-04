/* Set of utility routines
*/

/* 
*  Update env variables values depending on type and index
*/
function updateEnvVars(envVars, index) {
  const updatedEnvVars = {};
  let appendIndex=""
  if (index) {
    appendIndex=`${index+1}`;
  } else {
    return envVars;
  }
  for (envVar in envVars) {
    switch(envVar){
      case 'OPTIMIST_HOST': 
      case 'PROPOSER_HOST': 
      case 'OPTIMIST_HTTP_HOST': 
      case 'CHALLENGER_HOST': 
      case 'CIRCOM_WORKER_HOST': 
      case 'CLIENT_HOST': 
      case 'OPTIMIST_HTTP_URL': 
      case 'PROPOSER_URL':
      case 'OPTIMIST_WS_URL': 
      case 'CIRCOM_WORKER_URL': 
      case 'CLIENT_URL': 
        // split string by ., get 0th part and append number
        updatedEnvVars[envVar] = `${envVars[envVar].split('.')[0]}${appendIndex}.${process.env.DOMAIN_NAME}`;
        break;

      case 'OPTIMIST_DB':
      case 'COMMITMENTS_DB':
        updatedEnvVars[envVar] = `${envVars[envVar]}${appendIndex}`;
        break;

      default:
        updatedEnvVars[envVar] = envVars[envVar];
    }
  }
  return updatedEnvVars;
};

function findPriority(prioritySet, key) {
  if (key in prioritySet) return prioritySet[key];
  let nextUnused = 1;
  let matchFound = true;
  while (matchFound){
    matchFound = false
    for (const [_key, _value] of Object.entries(prioritySet)) {
      if (_value === Number(nextUnused)) {
        nextUnused++;
        matchFound = true;
        break;
      }
    }
  }
  return nextUnused;
}

  // https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html
function updateEcsCpus(desiredCpus) {
  let vcpus = 1024;
  if (desiredCpus === 0.25) { vcpus = 256; }
  else if (desiredCpus === 0.5) { vcpus = 512; }
  else if (desiredCpus === 1) { vcpus = 1024; }
  else if (desiredCpus <= 3) { vcpus = 1024 * 2; }
  else if (desiredCpus <= 4) { vcpus = 1024 * 4; }
  else if (desiredCpus <= 8) { vcpus = 1024 * 8; }
  else { vcpus = 1024 * 16; }

  return vcpus;
}

function getCircuitHashes(inputFile) {
  const fs = require('fs');
  let hashData;
  try {
    let rawdata = fs.readFileSync(inputFile);
    hashData = JSON.parse(rawdata);
  } catch (err) {
    return [];
  }
  const circuitHashShort = [];
  for (const circuitHash of hashData) {
    circuitHashShort.push({hash: circuitHash.circuitHash.substr(0,12), name: circuitHash.circuitName});
  }
  return circuitHashShort;
}

module.exports = {
  updateEnvVars,
  findPriority,
  updateEcsCpus,
  getCircuitHashes,
};
