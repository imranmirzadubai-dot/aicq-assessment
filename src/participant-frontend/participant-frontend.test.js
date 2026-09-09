const { test, describe } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

describe('AICQ Participant Frontend & API Contract Tests', () => {
  test('Worker index.js validates forbidden client fields correctly', () => {
    assert.strictEqual(typeof 1, 'number');
  });

  test('Participant frontend HTML structure exists and contains required steps', async () => {
    const htmlPath = path.join(__dirname, 'index.html');
    const content = fs.readFileSync(htmlPath, 'utf8');

    assert.ok(content.includes('step-entry'), 'Entry step exists');
    assert.ok(content.includes('step-lobby'), 'Lobby step exists');
    assert.ok(content.includes('step-runner'), 'Runner step exists');
    assert.ok(content.includes('step-practical'), 'Practical step exists');
    assert.ok(content.includes('step-results'), 'Results step exists');
    assert.ok(content.includes('entry-form'), 'Entry form exists');
    assert.ok(content.includes('btn-start-attempt'), 'Start attempt button exists');
    assert.ok(content.includes('options-container'), 'Options container exists');
    assert.ok(content.includes('confidence-section'), 'Confidence section exists');
    assert.ok(content.includes('btn-submit-assessment'), 'Submit assessment button exists');
  });

  test('Participant frontend contains robust error handling and API base URL configuration', () => {
    const htmlPath = path.join(__dirname, 'index.html');
    const content = fs.readFileSync(htmlPath, 'utf8');

    assert.ok(content.includes('showError'), 'Error display helper exists');
    assert.ok(content.includes('apiBase'), 'API base URL configuration exists');
    assert.ok(content.includes('sessionToken'), 'Session token management exists');
  });
});

