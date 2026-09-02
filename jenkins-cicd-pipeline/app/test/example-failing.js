'use strict';

// change to pass: set EXPECTED back to 'pass' to restore a green build.
// This file is GREEN by default. To demonstrate a FAILURE path, change EXPECTED
// to 'fail' below — the assertion will break and the Jenkins build will go red.
// Then change it back to 'pass' before running a normal pipeline again.
const { test } = require('node:test');
const assert = require('node:assert');

test('demonstrates how a test can be made to fail', () => {
  const EXPECTED = 'pass';
  const ACTUAL = 'pass';
  assert.strictEqual(
    ACTUAL,
    EXPECTED,
    'Intentionally failing test. Edit test/example-failing.js and set EXPECTED to "fail" to demonstrate a red build.'
  );
});
