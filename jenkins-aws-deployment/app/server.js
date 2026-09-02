'use strict';

const http = require('http');

const PORT = Number(process.env.PORT) || 3000;
const BUILD_VERSION = process.env.BUILD_VERSION || 'local-dev';
const HOSTNAME = process.env.HOSTNAME || 'unknown';
const STARTED_AT = new Date().toISOString();

function sendJson(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
  });
  res.end(body);
}

function sendHtml(res, statusCode, html) {
  res.writeHead(statusCode, {
    'Content-Type': 'text/html; charset=utf-8',
    'Content-Length': Buffer.byteLength(html),
  });
  res.end(html);
}

const server = http.createServer((req, res) => {
  const { url, method } = req;

  if (url === '/health') {
    const payload = {
      status: 'ok',
      service: 'node-app',
      buildVersion: BUILD_VERSION,
      uptimeSeconds: Math.round(process.uptime()),
      timestamp: new Date().toISOString(),
    };
    return sendJson(res, 200, payload);
  }

  if (url === '/api/message') {
    return sendJson(res, 200, {
      message: 'Hello from the Node.js app served behind Nginx on EC2!',
      buildVersion: BUILD_VERSION,
      host: HOSTNAME,
    });
  }

  if (url === '/') {
    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>DevOps Project - Jenkins + Docker + EC2</title>
  <style>
    body { font-family: system-ui, sans-serif; background: #0f172a; color: #e2e8f0;
           display: flex; min-height: 100vh; align-items: center; justify-content: center; margin: 0; }
    .card { background: #1e293b; border-radius: 12px; padding: 2rem 2.5rem;
            box-shadow: 0 8px 30px rgba(0,0,0,.35); max-width: 640px; }
    h1 { margin-top: 0; color: #38bdf8; }
    code { background: #0f172a; padding: .1rem .4rem; border-radius: 4px; color: #fbbf24; }
    a { color: #38bdf8; }
    ul { line-height: 1.7; }
  </style>
</head>
<body>
  <div class="card">
    <h1>&#128640; DevOps Pipeline - App is Running</h1>
    <p>This page is served by a <b>Node.js container</b> running on <b>AWS EC2</b>,
       with <b>Nginx</b> acting as a reverse proxy on port 80.</p>
    <ul>
      <li>Build version: <code>${BUILD_VERSION}</code></li>
      <li>Container host: <code>${HOSTNAME}</code></li>
      <li>Started at: <code>${STARTED_AT}</code></li>
    </ul>
    <p>
      Try the endpoints:
      <a href="/health">/health</a> |
      <a href="/api/message">/api/message</a>
    </p>
    <p style="font-size:.85rem; color:#94a3b8;">Git Push &rarr; Jenkins &rarr; Docker Build &rarr; Deploy to EC2 &rarr; Nginx &rarr; Internet</p>
  </div>
</body>
</html>`;
    return sendHtml(res, 200, html);
  }

  if (method !== 'GET') {
    return sendJson(res, 405, { status: 'error', message: `Method ${method} not allowed` });
  }

  return sendJson(res, 404, { status: 'error', message: `Not found: ${url}` });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[server] listening on 0.0.0.0:${PORT} (build: ${BUILD_VERSION})`);
});

process.on('SIGTERM', () => {
  console.log('[server] SIGTERM received, shutting down gracefully');
  server.close(() => process.exit(0));
});

process.on('SIGINT', () => {
  console.log('[server] SIGINT received, shutting down gracefully');
  server.close(() => process.exit(0));
});

module.exports = { server };
