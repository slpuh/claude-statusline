#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');

const REMOVE  = process.argv.includes('--remove') || process.argv.includes('-r');
const CLAUDE_DIR    = path.join(os.homedir(), '.claude');
const SCRIPT_DEST   = path.join(CLAUDE_DIR, 'statusline.sh');
const SETTINGS_FILE = path.join(CLAUDE_DIR, 'settings.json');

const STATUS_LINE_CONFIG = {
  type: 'command',
  command: 'bash ~/.claude/statusline.sh',
  refreshInterval: 5,
};

function readSettings() {
  if (!fs.existsSync(SETTINGS_FILE)) return {};
  try { return JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf8')); }
  catch { return {}; }
}

function writeSettings(obj) {
  fs.writeFileSync(SETTINGS_FILE, JSON.stringify(obj, null, 2) + '\n');
}

if (REMOVE) {
  if (fs.existsSync(SCRIPT_DEST)) {
    fs.unlinkSync(SCRIPT_DEST);
    console.log('✓ Removed ~/.claude/statusline.sh');
  } else {
    console.log('  statusline.sh not found, skipping');
  }

  const settings = readSettings();
  if (settings.statusLine) {
    delete settings.statusLine;
    writeSettings(settings);
    console.log('✓ Removed statusLine from ~/.claude/settings.json');
  }

  console.log('\nDone. Restart Claude Code to apply.');
  process.exit(0);
}

// ── install ───────────────────────────────────────────────────────────────────
if (!fs.existsSync(CLAUDE_DIR)) {
  console.error('Error: ~/.claude directory not found. Is Claude Code installed?');
  process.exit(1);
}

const scriptSrc = path.join(__dirname, '..', 'src', 'statusline.sh');
fs.copyFileSync(scriptSrc, SCRIPT_DEST);
execSync(`chmod +x "${SCRIPT_DEST}"`);
console.log('✓ Installed ~/.claude/statusline.sh');

const settings = readSettings();
if (settings.statusLine) {
  console.log('  statusLine already configured in settings.json — keeping existing');
} else {
  settings.statusLine = STATUS_LINE_CONFIG;
  writeSettings(settings);
  console.log('✓ Updated ~/.claude/settings.json');
}

console.log('\nDone. Restart Claude Code to see the statusline.');
