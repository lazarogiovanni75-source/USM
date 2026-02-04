/**
 * Request Validation Middleware
 * Validates request body against defined schemas
 */

const { AppError } = require('./errorHandler');

const validateRequired = (fields) => (req, res, next) => {
  const missing = [];
  
  for (const field of fields) {
    if (!req.body[field]) {
      missing.push(field);
    }
  }

  if (missing.length > 0) {
    throw new AppError(
      `Missing required fields: ${missing.join(', ')}`,
      400,
      'VALIDATION_ERROR'
    );
  }

  next();
};

const validateTypes = (schema) => (req, res, next) => {
  const errors = [];

  for (const [field, type] of Object.entries(schema)) {
    const value = req.body[field];
    
    if (value !== undefined) {
      const actualType = typeof value;
      
      if (actualType !== type) {
        errors.push(`Field '${field}' must be of type ${type}, got ${actualType}`);
      }
    }
  }

  if (errors.length > 0) {
    throw new AppError(
      errors.join('; '),
      400,
      'TYPE_VALIDATION_ERROR'
    );
  }

  next();
};

const sanitizeInput = (req, res, next) => {
  // Remove any potentially dangerous characters from string inputs
  if (req.body) {
    for (const [key, value] of Object.entries(req.body)) {
      if (typeof value === 'string') {
        // Basic XSS prevention - remove script tags
        req.body[key] = value.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '');
      }
    }
  }
  next();
};

module.exports = {
  validateRequired,
  validateTypes,
  sanitizeInput
};
