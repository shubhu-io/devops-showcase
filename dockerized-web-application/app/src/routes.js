'use strict';

function getHealth() {
  return {
    statusCode: 200,
    data: { status: 'ok' },
  };
}

async function getMessage({ checkDb }) {
  const dbConnected = await checkDb();
  return {
    statusCode: 200,
    data: {
      message: 'Hello from the dockerized application!',
      db: {
        status: dbConnected ? 'connected' : 'not-connected',
        detail: dbConnected
          ? 'TCP connection to the database succeeded.'
          : 'Could not reach the database. Check DB_HOST/DB_PORT and that the db service is healthy.',
      },
      timestamp: new Date().toISOString(),
    },
  };
}

module.exports = { getHealth, getMessage };
