/**
 * Monitoring and Health Check Endpoints
 * Provides comprehensive health, readiness, and metrics endpoints
 */

const os = require('os');
const { dbManager } = require('../database');

let startTime = Date.now();
let requestCount = 0;
let errorCount = 0;

// Track metrics
const trackRequest = () => {
  requestCount++;
};

const trackError = () => {
  errorCount++;
};

// Health check - basic liveness probe
const healthCheck = async (req, res) => {
  res.json({
    status: 'ok',
    service: 'ultimate-social-media-api',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
};

// Readiness check - detailed status of all dependencies
const readinessCheck = async (req, res) => {
  const checks = {
    server: 'ok',
    database: 'unknown',
    openai: 'unknown',
    poyo: 'unknown'
  };

  // Check database
  try {
    const dbStatus = dbManager.getStatus();
    checks.database = dbStatus.connected ? 'ok' : 'degraded';
  } catch (error) {
    checks.database = 'error';
  }

  // Check API keys
  checks.openai = process.env.OPENAI_API_KEY ? 'configured' : 'not_configured';
  checks.poyo = (process.env.POYO_API_KEY || process.env.DEFAPI_API_KEY) ? 'configured' : 'not_configured';

  // Overall status
  const isReady = checks.server === 'ok' && 
                  (checks.database === 'ok' || checks.database === 'degraded');

  res.status(isReady ? 200 : 503).json({
    status: isReady ? 'ready' : 'not_ready',
    checks,
    timestamp: new Date().toISOString()
  });
};

// Liveness check - for Railway/Kubernetes
const livenessCheck = async (req, res) => {
  res.json({
    status: 'alive',
    uptime: Math.floor((Date.now() - startTime) / 1000),
    timestamp: new Date().toISOString()
  });
};

// Metrics endpoint
const metricsCheck = async (req, res) => {
  const uptime = Math.floor((Date.now() - startTime) / 1000);
  const dbStatus = dbManager.getStatus();

  res.json({
    service: 'ultimate-social-media-api',
    uptime_seconds: uptime,
    requests: {
      total: requestCount,
      errors: errorCount,
      success_rate: requestCount > 0 ? ((requestCount - errorCount) / requestCount * 100).toFixed(2) + '%' : '100%'
    },
    database: {
      connected: dbStatus.connected,
      connection_attempts: dbStatus.attempts
    },
    system: {
      platform: os.platform(),
      arch: os.arch(),
      node_version: process.version,
      memory: {
        total: Math.round(os.totalmem() / 1024 / 1024) + 'MB',
        free: Math.round(os.freemem() / 1024 / 1024) + 'MB',
        used: Math.round((os.totalmem() - os.freemem()) / 1024 / 1024) + 'MB',
        usage: ((os.totalmem() - os.freemem()) / os.totalmem() * 100).toFixed(2) + '%'
      },
      cpu: {
        cores: os.cpus().length,
        model: os.cpus()[0]?.model || 'unknown'
      },
      load_average: os.loadavg()
    },
    environment: {
      node_env: process.env.NODE_ENV || 'development',
      has_openai_key: !!process.env.OPENAI_API_KEY,
      has_poyo_key: !!(process.env.POYO_API_KEY || process.env.DEFAPI_API_KEY),
      allowed_origins: process.env.ALLOWED_ORIGINS || 'not_set'
    },
    timestamp: new Date().toISOString()
  });
};

module.exports = {
  healthCheck,
  readinessCheck,
  livenessCheck,
  metricsCheck,
  trackRequest,
  trackError
};
