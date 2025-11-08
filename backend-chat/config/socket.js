// Socket.io instance manager
// This file prevents circular dependencies between server.js and controllers

let ioInstance = null;

export function setIO(io) {
  ioInstance = io;
}

export function getIO() {
  return ioInstance;
}

