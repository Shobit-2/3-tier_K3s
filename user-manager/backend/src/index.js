require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { pool, testConnection } = require('./db');
const userRoutes = require('./routes/users');

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors({ origin: '*' }));
app.use(express.json());

// Health endpoints
app.get('/health/live', (req, res) => res.status(200).json({ status: 'alive' }));

app.get('/health/ready', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.status(200).json({ status: 'ready' });
  } catch {
    res.status(503).json({ status: 'not ready' });
  }
});

app.use('/api/users', userRoutes);

const start = async () => {
  await testConnection();
  app.listen(PORT, '0.0.0.0', () => console.log(`Backend running on port ${PORT}`));
};

start();
# Updated
# trigger
