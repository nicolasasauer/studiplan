import express from 'express';
import rateLimit from 'express-rate-limit';
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

const app = express();
const PORT = process.env.PORT || 3000;
const DATA_FILE = process.env.DATA_FILE || '/data/plan.json';
const DIST_DIR = join(__dirname, '..', 'dist');

const apiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 120,
  standardHeaders: true,
  legacyHeaders: false,
});

app.use(express.json({ limit: '5mb' }));
app.use(express.static(DIST_DIR));

app.get('/api/plan', apiLimiter, (req, res) => {
  if (existsSync(DATA_FILE)) {
    try {
      const data = readFileSync(DATA_FILE, 'utf-8');
      res.json(JSON.parse(data));
    } catch {
      res.status(500).json({ error: 'Failed to read plan' });
    }
  } else {
    res.status(404).json({ error: 'No plan found' });
  }
});

app.put('/api/plan', apiLimiter, (req, res) => {
  try {
    const dir = dirname(DATA_FILE);
    if (!existsSync(dir)) {
      mkdirSync(dir, { recursive: true });
    }
    writeFileSync(DATA_FILE, JSON.stringify(req.body));
    res.json({ success: true });
  } catch {
    res.status(500).json({ error: 'Failed to save plan' });
  }
});

app.get('*', apiLimiter, (req, res) => {
  res.sendFile(join(DIST_DIR, 'index.html'));
});

app.listen(PORT, () => {
  console.log(`StudiumsPlaner server running on port ${PORT}`);
});
