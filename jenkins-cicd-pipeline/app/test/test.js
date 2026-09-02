'use strict';

const { test, before, after } = require('node:test');
const assert = require('node:assert');

const server = require('../server');

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
  assert.ok(body.status);
  assert.strictEqual(body.status, 'ok');
});

test('GET / returns 200 with hello html', async () => {
  const res = await fetch(`${BASE}/`);
  assert.strictEqual(res.status, 200);
  const text = await res.text();
  assert.ok(text.includes('Hello'));
  assert.match(text, /<html/i);
});

test('GET /api/message returns 200 with a message', async () => {
  const res = await fetch(`${BASE}/api/message`);
  assert.strictEqual(res.status, 200);
  const body = await res.json();
  assert.ok(body.message);
  assert.strictEqual(typeof body.message, 'string');
});

test('GET /unknown returns 404', async () => {
  const res = await fetch(`${BASE}/definitely-not-a-route`);
  assert.strictEqual(res.status, 404);
});
