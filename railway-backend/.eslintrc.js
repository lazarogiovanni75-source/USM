module.exports = {
  root: true,
  env: {
    browser: true,
    node: true,
    es2022: true
  },
  extends: [
    'eslint:recommended'
  ],
  parserOptions: {
    ecmaVersion: 'latest',
    sourceType: 'module'
  },
  rules: {
    'no-unused-vars': 'warn',
    'no-console': 'off',
    'prefer-const': 'error',
    'no-var': 'error'
  },
  globals: {
    require: 'readonly',
    module: 'readonly',
    process: 'readonly',
    Buffer: 'readonly',
    console: 'readonly',
    fetch: 'readonly',
    next: 'readonly',
    error: 'readonly'
  }
};