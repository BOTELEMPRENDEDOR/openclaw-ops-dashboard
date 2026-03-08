const express = require('express');
const cors = require('cors');
const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;
const ADMIN_USER = process.env.ADMIN_USER || 'admin';
const ADMIN_PASS = process.env.ADMIN_PASS || 'cl@w2026';

app.use(cors());
app.use(express.json());

// Auth middleware - for ALL routes
const requireAuth = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    return res.status(401).json({ error: 'Unauthorized', loginRequired: true });
  }
  
  try {
    const auth = Buffer.from(authHeader.split(' ')[1], 'base64').toString().split(':');
    const user = auth[0];
    const pass = auth[1];
    
    if (user === ADMIN_USER && pass === ADMIN_PASS) {
      return next();
    }
  } catch (e) {}
  
  return res.status(401).json({ error: 'Unauthorized', loginRequired: true });
};

// Login endpoint (public)
app.post('/api/login', express.json(), (req, res) => {
  const { user, pass } = req.body;
  if (user === ADMIN_USER && pass === ADMIN_PASS) {
    const token = Buffer.from(`${user}:${pass}`).toString('base64');
    res.json({ token, user });
  } else {
    res.status(401).json({ error: 'Invalid credentials' });
  }
});

// All other routes require auth
app.use('/api', requireAuth);
app.use('/', requireAuth);

// Dashboard HTML
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'dashboard.html'));
});

// API data
app.get('/api/data', (req, res) => {
  try {
    const collectScript = path.join(__dirname, 'collect.sh');
    const output = execSync(`bash ${collectScript}`, { encoding: 'utf-8', timeout: 30000 });
    const data = JSON.parse(output);
    res.json(data);
  } catch (error) {
    const dataPath = path.join(__dirname, 'data.json');
    if (fs.existsSync(dataPath)) {
      const staticData = JSON.parse(fs.readFileSync(dataPath, 'utf-8'));
      return res.json({ ...staticData, _fallback: true, _error: error.message });
    }
    res.status(500).json({ error: 'Failed to collect data', details: error.message });
  }
});

// Static data
app.get('/data.json', (req, res) => {
  const dataPath = path.join(__dirname, 'data.json');
  if (fs.existsSync(dataPath)) {
    res.sendFile(dataPath);
  } else {
    res.status(404).json({ error: 'data.json not found' });
  }
});

app.listen(PORT, () => {
  console.log(`OpenClaw Ops Dashboard running at http://localhost:${PORT}`);
  console.log(`Auth: ${ADMIN_USER} / ${ADMIN_PASS}`);
});
