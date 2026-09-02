'use strict';

const http = require('http');

const PORT = Number(process.env.PORT) || 3000;
const VERSION = process.env.npm_package_version || '1.0.0';

function send(res, statusCode, contentType, body) {
  res.writeHead(statusCode, { 'Content-Type': contentType });
  res.end(body);
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

  if (req.method === 'GET' && url.pathname === '/') {
    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Hello App</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 42rem; margin: 3rem auto; padding: 0 1rem; color: #1a1a1a; }
    code { background: #f0f0f0; padding: 0.15rem 0.35rem; border-radius: 4px; }
    .badge { display:inline-block; background:#2c7a4b; color:#fff; padding:0.15rem 0.5rem; border-radius:999px; font-size:0.8rem; }
  </style>
</head>
<body>
  <h1>Hello from the Jenkins CI/CD Pipeline</h1>
  <p><span class="badge">healthy</span></p>
  <p>This Node app is built with only the built-in <code>http</code> module &mdash; zero npm dependencies.</p>
  <ul>
    <li><a href="/health">GET /health</a> &mdash; JSON <code>{"status":"ok"}</code></li>
    <li><a href="/api/message">GET /api/message</a> &mdash; JSON greeting message</li>
  </ul>
</body>
</html>`;
    return send(res, 200, 'text/html; charset=utf-8', html);
  }

  if (req.method === 'GET' && url.pathname === '/health') {
    return send(res, 200, 'application/json', JSON.stringify({ status: 'ok' }));
  }

  if (req.method === 'GET' && url.pathname === '/api/message') {
    return send(
      res,
      200,
      'application/json',
      JSON.stringify({ message: 'Hello from the CI/CD pipeline!', version: VERSION })
    );
  }

  return send(res, 404, 'application/json', JSON.stringify({ error: 'not found' }));
});

server.listen(PORT, () => {
  console.log(`hello-app listening on http://localhost:${PORT}`);
});

module.exports = server;
