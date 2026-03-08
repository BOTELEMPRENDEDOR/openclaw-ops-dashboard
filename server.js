const express = require('express');
const cors = require('cors');
const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Serve static dashboard.html
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'dashboard.html'));
});

// API endpoint to execute collect.sh and return JSON
app.get('/api/data', (req, res) => {
  try {
    const collectScript = path.join(__dirname, 'collect.sh');
    const output = execSync(`bash ${collectScript}`, { encoding: 'utf-8' });
    const data = JSON.parse(output);
    res.json(data);
  } catch (error) {
    console.error('Error executing collect.sh:', error.message);
    res.status(500).json({ error: 'Failed to collect data', details: error.message });
  }
});

// Fallback: serve static data.json if API fails and file exists
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
  console.log(`API: http://localhost:${PORT}/api/data`);
  console.log(`Static data: http://localhost:${PORT}/data.json`);
});
