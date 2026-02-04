/**
 * Central Error Handler Middleware
 * Catches all errors and returns consistent JSON responses
 */

class AppError extends Error {
  constructor(message, statusCode = 500, errorCode = 'INTERNAL_ERROR') {
    super(message);
    this.statusCode = statusCode;
    this.errorCode = errorCode;
    this.isOperational = true;
    Error.captureStackTrace(this, this.constructor);
  }
}

const errorHandler = (err, req, res, next) => {
  let { statusCode, message, errorCode } = err;

  // Default to 500 if not set
  statusCode = statusCode || 500;
  errorCode = errorCode || 'INTERNAL_ERROR';

  // Log error details (but not sensitive data)
  console.error('[ERROR]', {
    timestamp: new Date().toISOString(),
    method: req.method,
    path: req.path,
    statusCode,
    errorCode,
    message: message || 'Unknown error',
    stack: process.env.NODE_ENV === 'development' ? err.stack : undefined
  });

  // Don't leak error details in production
  const response = {
    success: false,
    error: {
      code: errorCode,
      message: statusCode === 500 && process.env.NODE_ENV === 'production'
        ? 'Internal server error'
        : message || 'An error occurred'
    }
  };

  // Include stack trace in development
  if (process.env.NODE_ENV === 'development') {
    response.error.stack = err.stack;
  }

  res.status(statusCode).json(response);
};

// Async wrapper to catch errors in async route handlers
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

// 404 handler
const notFoundHandler = (req, res) => {
  res.status(404).json({
    success: false,
    error: {
      code: 'NOT_FOUND',
      message: `Cannot ${req.method} ${req.path}`
    }
  });
};

module.exports = {
  AppError,
  errorHandler,
  asyncHandler,
  notFoundHandler
};
