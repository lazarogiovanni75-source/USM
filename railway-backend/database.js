const { Pool } = require('pg');

const createPool = () => {
  if (process.env.DATABASE_URL) {
    return new Pool({
      connectionString: process.env.DATABASE_URL,
      ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
    });
  } else {
    return new Pool({
      host: process.env.POSTGRE_SQL_INNER_HOST || '127.0.0.1',
      port: process.env.POSTGRE_SQL_INNER_PORT || '5432',
      user: process.env.POSTGRE_SQL_USER || 'postgres',
      password: process.env.POSTGRE_SQL_PASSWORD || 'pgBqpmYZ',
      database: process.env.POSTGRE_SQL_DB || 'clacky_app_db',
      ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
    });
  }
};

const pool = createPool();

const query = async (text, params) => {
  const result = await pool.query(text, params);
  return result;
};

const close = async () => {
  await pool.end();
};

// User operations
const userOperations = {
  async create(name, email) {
    const result = await pool.query(
      'INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *',
      [name, email]
    );
    return result.rows[0];
  },
  async findById(id) {
    const result = await pool.query('SELECT * FROM users WHERE id = $1', [id]);
    return result.rows[0];
  },
  async findByEmail(email) {
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    return result.rows[0];
  },
  async findOrCreate(name, email) {
    let user = await this.findByEmail(email);
    if (!user) {
      user = await this.create(name, email);
    }
    return user;
  }
};

// Draft operations
const draftOperations = {
  async create(userId, text, status = 'pending') {
    const result = await pool.query(
      'INSERT INTO drafts (user_id, text, status) VALUES ($1, $2, $3) RETURNING *',
      [userId, text, status]
    );
    return result.rows[0];
  },
  async findById(id) {
    const result = await pool.query('SELECT * FROM drafts WHERE id = $1', [id]);
    return result.rows[0];
  },
  async findByUserId(userId) {
    const result = await pool.query('SELECT * FROM drafts WHERE user_id = $1 ORDER BY created_at DESC', [userId]);
    return result.rows;
  },
  async findByStatus(status) {
    const result = await pool.query('SELECT * FROM drafts WHERE status = $1 ORDER BY created_at DESC', [status]);
    return result.rows;
  },
  async updateStatus(id, status) {
    const result = await pool.query(
      'UPDATE drafts SET status = $1 WHERE id = $2 RETURNING *',
      [status, id]
    );
    return result.rows[0];
  },
  async getAll() {
    const result = await pool.query('SELECT * FROM drafts ORDER BY created_at DESC');
    return result.rows;
  }
};

// Video job operations
const videoJobOperations = {
  async create(jobId, userId, prompt, status = 'pending') {
    const result = await pool.query(
      'INSERT INTO video_jobs (job_id, user_id, prompt, status) VALUES ($1, $2, $3, $4) RETURNING *',
      [jobId, userId, prompt, status]
    );
    return result.rows[0];
  },
  async findByJobId(jobId) {
    const result = await pool.query('SELECT * FROM video_jobs WHERE job_id = $1', [jobId]);
    return result.rows[0];
  },
  async findByUserId(userId) {
    const result = await pool.query('SELECT * FROM video_jobs WHERE user_id = $1 ORDER BY created_at DESC', [userId]);
    return result.rows;
  },
  async updateStatus(jobId, status, videoUrl = null) {
    const result = await pool.query(
      'UPDATE video_jobs SET status = $1, video_url = $2 WHERE job_id = $3 RETURNING *',
      [status, videoUrl, jobId]
    );
    return result.rows[0];
  },
  async getAll() {
    const result = await pool.query('SELECT * FROM video_jobs ORDER BY created_at DESC');
    return result.rows;
  }
};

module.exports = { pool, query, close, users: userOperations, drafts: draftOperations, videoJobs: videoJobOperations };
