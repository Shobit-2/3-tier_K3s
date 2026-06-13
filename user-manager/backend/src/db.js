const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST || 'postgres-service.db.svc.cluster.local',
  port: parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME || 'usermanager',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

const testConnection = async () => {
  let retries = 10;
  while (retries > 0) {
    try {
      const client = await pool.connect();
      console.log('PostgreSQL connected');
      await client.query(`
        CREATE TABLE IF NOT EXISTS users (
          id SERIAL PRIMARY KEY,
          name VARCHAR(100) NOT NULL,
          email VARCHAR(150) UNIQUE NOT NULL,
          password VARCHAR(255) NOT NULL,
          role VARCHAR(50) DEFAULT 'user',
          created_at TIMESTAMP DEFAULT NOW()
        )
      `);
      console.log('Table ready');
      client.release();
      return;
    } catch (err) {
      console.error(`DB connection failed (${retries} retries left):`, err.message);
      retries--;
      await new Promise(r => setTimeout(r, 3000));
    }
  }
  throw new Error('Could not connect to DB after retries');
};

module.exports = { pool, testConnection };
