/*
 * This module contains the logic needed to report nightfall status
 */

let status = 'OK';
let oldStatus = 'OK';
let alarms = {};

export function getStatus() {
  return status;
}

export function setCriticalStatus() {
  oldStatus = 'KO';
}

export function updateStatus() {
  status = oldStatus;
}

export function clearStatus() {
  oldStatus = 'OK';
}

export function updateDetailedStatus(_status) {
  alarms = _status;
}

export function getDetailedStatus() {
  return alarms;
}
