/**
 * Request Logger Middleware
 * Logs all incoming requests with timing information
 */

const logger = (req, res, next) => {
  const start = Date.now();
  
  // Log request
  console.log('[REQUEST]', {
    timestamp: new Date().toISOString(),
    method: req.method,
    path: req.path,
    ip: req.ip || req.connection.remoteAddress,
    userAgent: req.get('user-agent')
  });

  // Log response when finished
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log('[RESPONSE]', {
      timestamp: new Date().toISOString(),
      method: req.method,
      path: req.path,
      status: res.statusCode,
      duration: `${duration}ms`
    });
  });

  next();
};

module.exports = logger;
