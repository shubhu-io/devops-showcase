'use strict';

const { test, before, after } = require('node:test');
const assert = require('node:assert');

const { server } = require('../server');

const PORT = Number(process.env.PORT) || 3000;
const BASE = `http://127.0.0.1:${PORT}`;

before(async () => {
  if (!server.listening) {
    await new Promise((resolve) => server.once('listening', resolve));
  }
});

after(() => {
  server.close();
});

test('GET /health returns 200 with status ok', async () => {
  const res = await fetch(`${BASE}/health`);
  assert.strictEqual(res.status, 200);
  const body = await res.json();
  assert.strictEqual(body.status, 'ok');
  assert.ok(body.buildVersion, 'buildVersion field is present');
});

test('GET / returns 200 with html body', async () => {
  const res = await fetch(`${BASE}/`);
  assert.strictEqual(res.status, 200);
  const contentType = res.headers.get('content-type') || '';
  assert.match(contentType, /text\/html/);
  const body = await res.text();
  assert.match(body, /DevOps Pipeline - App is Running/);
});

test('GET /api/message returns 200 with json body', async () => {
  const res = await fetch(`${BASE}/api/message`);
  assert.strictEqual(res.status, 200);
  const body = await res.json();
  assert.ok(body.message, 'message field is present');
  assert.match(body.message, /Hello/);
});

test('GET /unknown returns 404 json', async () => {
  const res = await fetch(`${BASE}/definitely-not-a-route`);
  assert.strictEqual(res.status, 404);
  const body = await res.json();
  assert.strictEqual(body.status, 'error');
});
