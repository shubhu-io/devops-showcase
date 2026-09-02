'use strict';
const http = require('http');
const PORT = Number(process.env.PORT) || 3000;
const VERSION = process.env.GITHUB_SHA ? process.env.GITHUB_SHA.slice(0,7) : 'local';
const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host||'localhost'}`);
  if (req.method==='GET' && url.pathname==='/health') {
    res.writeHead(200, {'Content-Type':'application/json'}); res.end(JSON.stringify({status:'ok', version: VERSION}));
    return;
  }
  if (req.method==='GET' && url.pathname==='/') {
    const html=`<!DOCTYPE html><html><head><meta charset="utf-8"><title>Actions Demo</title><style>body{font-family:system-ui;display:grid;place-items:center;min-height:100vh;margin:0;background:#0f172a;color:#e2e8f0}main{background:#1e293b;padding:2rem;border-radius:12px}</style></head><body><main><h1>GitHub Actions Demo App</h1><p>Version <code>${VERSION}</code></p><p><a href="/health">/health</a></p></main></body></html>`;
    res.writeHead(200, {'Content-Type':'text/html'}); res.end(html); return;
  }
  res.writeHead(404, {'Content-Type':'application/json'}); res.end(JSON.stringify({error:'not found'}));
});
if (require.main===module) server.listen(PORT, '0.0.0.0', ()=>console.log(`listening ${PORT} ${VERSION}`));
module.exports=server;
