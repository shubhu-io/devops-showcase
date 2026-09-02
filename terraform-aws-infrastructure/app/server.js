'use strict';

const http = require('http');

const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

// On AWS EC2 the instance ID is reachable from inside the box via the
// instance metadata service (IMDSv2 needs a token, so this is best-effort).
const METADATA_BASE = 'http://169.254.169.254/latest/meta-data';

function fetchMetadata(path, timeoutMs = 2000) {
  return new Promise((resolve) => {
    const req = http.get(`${METADATA_BASE}/${path}`, { timeout: timeoutMs }, (res) => {
      let body = '';
      res.on('data', (c) => (body += c));
      res.on('end', () => resolve(body.trim().slice(0, 64) || null));
    });
    req.on('error', () => resolve(null));
    req.on('timeout', () => {
      req.destroy();
      resolve(null);
    });
  });
}

async function getInstanceId() {
  try {
    const token = await new Promise((resolve) => {
      const req = http.request(
        `${METADATA_BASE}/api/token`,
        { method: 'PUT', headers: { 'X-aws-ec2-metadata-token-ttl-seconds': '60' }, timeout: 2000 },
        (res) => {
          let b = '';
          res.on('data', (c) => (b += c));
          res.on('end', () => resolve(b || null));
        }
      );
      req.on('error', () => resolve(null));
      req.on('timeout', () => { req.destroy(); resolve(null); });
      req.end();
    });

    if (!token) return null;

    const meta = await new Promise((resolve) => {
      const req = http.get(
        `${METADATA_BASE}/instance-id`,
        { headers: { 'X-aws-ec2-metadata-token': token }, timeout: 2000 },
        (res) => {
          let b = '';
          res.on('data', (c) => (b += c));
          res.on('end', () => resolve(b.trim() || null));
        }
      );
      req.on('error', () => resolve(null));
      req.on('timeout', () => { req.destroy(); resolve(null); });
      req.end();
    });

    return meta;
  } catch {
    return null;
  }
}

function renderHome(instanceId, hostname) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Hello from the Terraform Demo App</title>
  <style>
    body { font-family: system-ui, sans-serif; background: #0f172a; color: #e2e8f0;
           display: grid; place-items: center; min-height: 100vh; margin: 0; }
    main { max-width: 640px; padding: 2rem; border: 1px solid #334155; border-radius: 12px;
           background: #1e293b; text-align: center; }
    code { background: #0f172a; padding: 0.15rem 0.4rem; border-radius: 6px; color: #7dd3fc; }
    .meta { font-size: 0.85rem; color: #94a3b8; }
  </style>
</head>
<body>
  <main>
    <h1>Hello from the Terraform Demo App</h1>
    <p>You reached this page through the full stack:</p>
    <p><code>Internet &rarr; VPC &rarr; Public Subnet &rarr; EC2 &rarr; Docker &rarr; Nginx &rarr; Node.js</code></p>
    <p class="meta">Container hostname: <code>${hostname}</code><br/>Instance ID: <code>${instanceId || 'unknown (not on EC2)'}</code></p>
    <p><a href="/health" style="color:#7dd3fc;">Check /health</a></p>
  </main>
</body>
</html>`;
}

function createServer() {
  return http.createServer(async (req, res) => {
    const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

    if (req.method === 'GET' && url.pathname === '/health') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'ok', uptime: process.uptime(), timestamp: new Date().toISOString() }));
      return;
    }

    if (req.method === 'GET' && url.pathname === '/') {
      const instanceId = await getInstanceId();
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(renderHome(instanceId, require('os').hostname()));
      return;
    }

    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'not found' }));
  });
}

if (process.argv.includes('--selftest')) {
  createServer()
    .listen(PORT, HOST)
    .on('listening', () => {
      http
        .get({ host: '127.0.0.1', port: PORT, path: '/health' }, (res) => {
          let body = '';
          res.on('data', (c) => (body += c));
          res.on('end', () => {
            const ok = res.statusCode === 200 && JSON.parse(body).status === 'ok';
            console.log(ok ? 'SELFTEST PASS' : `SELFTEST FAIL: ${body}`);
            process.exit(ok ? 0 : 1);
          });
        })
        .on('error', (err) => {
          console.error('SELFTEST FAIL', err.message);
          process.exit(1);
        });
    });
} else {
  createServer().listen(PORT, HOST, () => {
    console.log(`App listening on http://${HOST}:${PORT}`);
  });
}
