const express = require('express');
const cors = require('cors');
const { execFileSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;
const IS_VERCEL = Boolean(process.env.VERCEL);
const ADMIN_USER = process.env.ADMIN_USER || '';
const ADMIN_PASS = process.env.ADMIN_PASS || '';
const HAS_AUTH_CONFIG = Boolean(ADMIN_USER && ADMIN_PASS);
const AUTH_DISABLED = process.env.DISABLE_AUTH === '1';
const DATA_FILE = path.join(__dirname, 'data.json');
const COLLECT_SCRIPT = path.join(__dirname, 'collect.sh');

app.disable('x-powered-by');
app.use(cors());
app.use(express.json({ limit: '16kb' }));
app.use((req, res, next) => {
  res.set('Cache-Control', 'no-store');
  next();
});

function getBasicAuth(req) {
  const authHeader = req.headers.authorization || '';
  if (!authHeader.startsWith('Basic ')) return null;

  try {
    const decoded = Buffer.from(authHeader.slice(6), 'base64').toString('utf8');
    const separator = decoded.indexOf(':');
    if (separator === -1) return null;
    return {
      user: decoded.slice(0, separator),
      pass: decoded.slice(separator + 1),
    };
  } catch {
    return null;
  }
}

function isAuthorized(req) {
  if (AUTH_DISABLED) return true;
  if (!HAS_AUTH_CONFIG) return false;

  const auth = getBasicAuth(req);
  return !!auth && auth.user === ADMIN_USER && auth.pass === ADMIN_PASS;
}

function requireAuth(req, res, next) {
  if (isAuthorized(req)) return next();

  if (!HAS_AUTH_CONFIG) {
    return res.status(503).json({
      error: 'Auth is not configured',
      code: 'AUTH_NOT_CONFIGURED',
      loginRequired: true,
    });
  }

  res.set('WWW-Authenticate', 'Basic realm="OpenClaw Ops Dashboard"');
  return res.status(401).json({ error: 'Unauthorized', code: 'UNAUTHORIZED', loginRequired: true });
}

function loadStaticData() {
  if (!fs.existsSync(DATA_FILE)) {
    return null;
  }

  return JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
}

function collectRealtimeData() {
  const output = execFileSync('bash', [COLLECT_SCRIPT], {
    encoding: 'utf8',
    timeout: 30000,
    env: process.env,
  });

  return JSON.parse(output);
}

function getDashboardData() {
  try {
    const realtime = collectRealtimeData();
    return {
      ...realtime,
      _meta: {
        runtime: IS_VERCEL ? 'vercel' : 'node',
        mode: 'realtime',
        authConfigured: HAS_AUTH_CONFIG || AUTH_DISABLED,
      },
    };
  } catch (error) {
    const staticData = loadStaticData();
    if (!staticData) {
      throw error;
    }

    return {
      ...staticData,
      _fallback: true,
      _meta: {
        runtime: IS_VERCEL ? 'vercel' : 'node',
        mode: 'static-fallback',
        authConfigured: HAS_AUTH_CONFIG || AUTH_DISABLED,
      },
      _error: error.message,
    };
  }
}

app.post('/api/login', (req, res) => {
  if (AUTH_DISABLED) {
    return res.json({ token: 'auth-disabled', user: 'auth-disabled', authDisabled: true });
  }

  if (!HAS_AUTH_CONFIG) {
    return res.status(503).json({
      error: 'ADMIN_USER y ADMIN_PASS no están configurados',
      code: 'AUTH_NOT_CONFIGURED',
    });
  }

  const { user, pass } = req.body || {};
  if (user === ADMIN_USER && pass === ADMIN_PASS) {
    const token = Buffer.from(`${user}:${pass}`).toString('base64');
    return res.json({ token, user });
  }

  return res.status(401).json({ error: 'Invalid credentials', code: 'INVALID_CREDENTIALS' });
});

app.get('/healthz', (_req, res) => {
  const staticDataAvailable = fs.existsSync(DATA_FILE);
  res.json({
    ok: true,
    runtime: IS_VERCEL ? 'vercel' : 'node',
    auth: {
      enabled: !AUTH_DISABLED,
      configured: HAS_AUTH_CONFIG,
    },
    fallback: {
      staticDataAvailable,
      collectScriptPresent: fs.existsSync(COLLECT_SCRIPT),
    },
  });
});

app.get('/', (_req, res) => {
  res.sendFile(path.join(__dirname, 'dashboard.html'));
});

app.get('/api/data', requireAuth, (req, res) => {
  try {
    return res.json(getDashboardData());
  } catch (error) {
    return res.status(500).json({ error: 'Failed to collect data', details: error.message });
  }
});

app.get('/data.json', requireAuth, (req, res) => {
  if (fs.existsSync(DATA_FILE)) {
    return res.sendFile(DATA_FILE);
  }
  return res.status(404).json({ error: 'data.json not found' });
});

module.exports = app;

if (!IS_VERCEL) {
  app.listen(PORT, () => {
    console.log(`OpenClaw Ops Dashboard running at http://localhost:${PORT}`);
    console.log(`Auth enabled: ${AUTH_DISABLED ? 'no' : 'yes'}`);
    console.log(`Auth configured: ${HAS_AUTH_CONFIG ? 'yes' : 'no'}`);
  });
}
