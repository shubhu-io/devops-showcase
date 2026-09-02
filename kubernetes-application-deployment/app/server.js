'use strict';

const http = require('http');

const PORT = Number(process.env.PORT) || 3000;
const VERSION = process.env.APP_VERSION || '1.0.0';

function sendJson(res, code, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(code, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
  });
  res.end(body);
}

function sendHtml(res, code, html) {
  res.writeHead(code, {
    'Content-Type': 'text/html; charset=utf-8',
    'Content-Length': Buffer.byteLength(html),
  });
  res.end(html);
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

  if (req.method === 'GET' && url.pathname === '/health') {
    return sendJson(res, 200, { status: 'ok', version: VERSION, uptime: Math.round(process.uptime()) });
  }

  if (req.method === 'GET' && url.pathname === '/ready') {
    return sendJson(res, 200, { status: 'ready' });
  }

  if (req.method === 'GET' && url.pathname === '/api/message') {
    return sendJson(res, 200, { message: 'Hello from Kubernetes!', version: VERSION });
  }

  if (req.method === 'GET' && url.pathname === '/') {
    const html = `<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>K8s Demo App</title>
<style>body{font-family:system-ui,sans-serif;display:grid;place-items:center;min-height:100vh;margin:0;background:#0f172a;color:#e2e8f0}main{background:#1e293b;padding:2rem;border-radius:12px;max-width:560px;text-align:center;border:1px solid #334155}code{background:#0f172a;padding:.15rem .4rem;border-radius:6px;color:#7dd3fc}a{color:#7dd3fc}</style></head>
<body><main><h1>Kubernetes Demo App</h1><p>Version <code>${VERSION}</code> — served from a K8s Deployment.</p><p><a href="/health">/health</a> · <a href="/ready">/ready</a> · <a href="/api/message">/api/message</a></p></main></body></html>`;
    return sendHtml(res, 200, html);
  }

  return sendJson(res, 404, { error: 'not found', path: url.pathname });
});

if (require.main === module) {
  server.listen(PORT, '0.0.0.0', () => {
    console.log(`[server] listening on 0.0.0.0:${PORT} version=${VERSION}`);
  });
}

process.on('SIGTERM', () => {
  console.log('[server] SIGTERM, shutting down');
  server.close(() => process.exit(0));
});

module.exports = server;
