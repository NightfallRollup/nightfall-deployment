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

module.exports = {
  updateEnvVars,
  findPriority,
};
