'use strict';

const http = require('http');
const net = require('net');
const routes = require('./src/routes');

const PORT = Number(process.env.PORT || 3000);
const DB_HOST = process.env.DB_HOST || 'db';
const DB_PORT = Number(process.env.DB_PORT || 5432);

const HTML_PAGE = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Dockerized Application</title>
  <style>
    body { font-family: -apple-system, Segoe UI, Roboto, sans-serif; background: #f4f6f8; margin: 0; }
    .card { max-width: 640px; margin: 60px auto; background: #fff; border-radius: 10px;
            box-shadow: 0 4px 20px rgba(0,0,0,.08); padding: 40px; }
    h1 { color: #1f2d3d; margin-top: 0; }
    code { background: #eef2f7; padding: 2px 6px; border-radius: 4px; font-size: .9em; }
    ul { line-height: 1.8; }
    .badge { display: inline-block; padding: 4px 10px; border-radius: 12px; font-size: .8em; font-weight: 600; }
    .ok { background: #e6f7ec; color: #1e7e34; }
    .warn { background: #fff3cd; color: #856404; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Dockerized Application</h1>
    <p>You reached the Node.js application through the Nginx reverse proxy.</p>
    <p><span class="badge ok">OK</span>&nbsp; Server is running on port <code>${PORT}</code></p>
    <ul>
      <li><a href="/health">GET /health</a> — JSON health status</li>
      <li><a href="/api/message">GET /api/message</a> — message + DB connectivity status</li>
    </ul>
    <p><small>DB target: <code>${DB_HOST}:${DB_PORT}</code></small></p>
  </div>
</body>
</html>`;

function dbConnectivityCheck() {
  return new Promise((resolve) => {
    const socket = new net.Socket();
    const timeout = setTimeout(() => {
      socket.destroy();
      resolve(false);
    }, 2500);
    socket.setTimeout(2500);
    socket.on('connect', () => {
      clearTimeout(timeout);
      socket.end();
      resolve(true);
    });
    socket.on('timeout', () => {
      clearTimeout(timeout);
      socket.destroy();
      resolve(false);
    });
    socket.on('error', () => {
      clearTimeout(timeout);
      resolve(false);
    });
    socket.connect({ host: DB_HOST, port: DB_PORT });
  });
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);

  if (url.pathname === '/') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(HTML_PAGE);
    return;
  }

  if (url.pathname === '/health') {
    const handler = routes.getHealth;
    const body = handler();
    res.writeHead(body.statusCode, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify(body.data));
    return;
  }

  if (url.pathname === '/api/message') {
    const handler = routes.getMessage;
    const body = await handler({ checkDb: dbConnectivityCheck });
    res.writeHead(body.statusCode, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify(body.data));
    return;
  }

  res.writeHead(404, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify({ error: 'Not found', path: url.pathname }));
});

server.listen(PORT, () => {
  console.log(`[server] listening on port ${PORT}`);
  console.log(`[server] configured DB target ${DB_HOST}:${DB_PORT}`);
});

process.on('SIGTERM', () => {
  console.log('[server] SIGTERM received, shutting down');
  server.close(() => process.exit(0));
});
