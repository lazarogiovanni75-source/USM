const { Pool } = require('pg');

class DatabaseManager {
  constructor() {
    this.pool = null;
    this.isConnected = false;
    this.connectionAttempts = 0;
    this.maxRetries = 5;
    this.retryDelay = 5000; // 5 seconds
  }

  createPool() {
    const config = process.env.DATABASE_URL
      ? {
          connectionString: process.env.DATABASE_URL,
          ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
          max: 20, // Maximum pool size
          idleTimeoutMillis: 30000, // Close idle clients after 30 seconds
          connectionTimeoutMillis: 10000, // 10 second connection timeout
        }
      : {
          host: process.env.POSTGRE_SQL_INNER_HOST || '127.0.0.1',
          port: process.env.POSTGRE_SQL_INNER_PORT || '5432',
          user: process.env.POSTGRE_SQL_USER || 'postgres',
          password: process.env.POSTGRE_SQL_PASSWORD || 'pgBqpmYZ',
          database: process.env.POSTGRE_SQL_DB || 'clacky_app_db',
          ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
          max: 20,
          idleTimeoutMillis: 30000,
          connectionTimeoutMillis: 10000,
        };

    return new Pool(config);
  }

  async connect() {
    if (this.isConnected && this.pool) {
      return this.pool;
    }

    try {
      this.pool = this.createPool();

      // Test connection
      await this.pool.query('SELECT 1');
      this.isConnected = true;
      this.connectionAttempts = 0;

      console.log('[DATABASE] Connected successfully');

      // Handle pool errors
      this.pool.on('error', (err) => {
        console.error('[DATABASE] Pool error:', err);
        this.isConnected = false;
      });

      return this.pool;
    } catch (error) {
      console.error('[DATABASE] Connection failed:', error.message);
      this.isConnected = false;
      this.connectionAttempts++;

      // Auto-retry connection
      if (this.connectionAttempts < this.maxRetries) {
        console.log(`[DATABASE] Retrying connection (${this.connectionAttempts}/${this.maxRetries}) in ${this.retryDelay}ms...`);
        setTimeout(() => this.connect(), this.retryDelay);
      } else {
        console.error('[DATABASE] Max connection retries reached. Running in degraded mode.');
      }

      return null;
    }
  }

  async query(text, params) {
    if (!this.isConnected || !this.pool) {
      throw new Error('Database not connected');
    }

    try {
      const result = await this.pool.query(text, params);
      return result;
    } catch (error) {
      console.error('[DATABASE] Query error:', error.message);
      throw error;
    }
  }

  async close() {
    if (this.pool) {
      await this.pool.end();
      this.isConnected = false;
      console.log('[DATABASE] Connection closed');
    }
  }

  getStatus() {
    return {
      connected: this.isConnected,
      attempts: this.connectionAttempts,
      maxRetries: this.maxRetries
    };
  }
}

// Singleton instance
const dbManager = new DatabaseManager();

// User operations
const userOperations = {
  async create(name, email) {
    const result = await dbManager.query(
      'INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *',
      [name, email]
    );
    return result.rows[0];
  },
  async findById(id) {
    const result = await dbManager.query('SELECT * FROM users WHERE id = $1', [id]);
    return result.rows[0];
  },
  async findByEmail(email) {
    const result = await dbManager.query('SELECT * FROM users WHERE email = $1', [email]);
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
    const result = await dbManager.query(
      'INSERT INTO drafts (user_id, text, status) VALUES ($1, $2, $3) RETURNING *',
      [userId, text, status]
    );
    return result.rows[0];
  },
  async findById(id) {
    const result = await dbManager.query('SELECT * FROM drafts WHERE id = $1', [id]);
    return result.rows[0];
  },
  async findByUserId(userId) {
    const result = await dbManager.query('SELECT * FROM drafts WHERE user_id = $1 ORDER BY created_at DESC', [userId]);
    return result.rows;
  },
  async findByStatus(status) {
    const result = await dbManager.query('SELECT * FROM drafts WHERE status = $1 ORDER BY created_at DESC', [status]);
    return result.rows;
  },
  async updateStatus(id, status) {
    const result = await dbManager.query(
      'UPDATE drafts SET status = $1 WHERE id = $2 RETURNING *',
      [status, id]
    );
    return result.rows[0];
  },
  async getAll() {
    const result = await dbManager.query('SELECT * FROM drafts ORDER BY created_at DESC');
    return result.rows;
  }
};

// Video job operations
const videoJobOperations = {
  async create(jobId, userId, prompt, status = 'pending') {
    const result = await dbManager.query(
      'INSERT INTO video_jobs (job_id, user_id, prompt, status) VALUES ($1, $2, $3, $4) RETURNING *',
      [jobId, userId, prompt, status]
    );
    return result.rows[0];
  },
  async findByJobId(jobId) {
    const result = await dbManager.query('SELECT * FROM video_jobs WHERE job_id = $1', [jobId]);
    return result.rows[0];
  },
  async findByUserId(userId) {
    const result = await dbManager.query('SELECT * FROM video_jobs WHERE user_id = $1 ORDER BY created_at DESC', [userId]);
    return result.rows;
  },
  async updateStatus(jobId, status, videoUrl = null) {
    const result = await dbManager.query(
      'UPDATE video_jobs SET status = $1, video_url = $2 WHERE job_id = $3 RETURNING *',
      [status, videoUrl, jobId]
    );
    return result.rows[0];
  },
  async getAll() {
    const result = await dbManager.query('SELECT * FROM video_jobs ORDER BY created_at DESC');
    return result.rows;
  }
};

module.exports = {
  dbManager,
  query: (text, params) => dbManager.query(text, params),
  close: () => dbManager.close(),
  users: userOperations,
  drafts: draftOperations,
  videoJobs: videoJobOperations
};
