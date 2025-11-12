// Rate limiting middleware for API service
import rateLimit from 'express-rate-limit';

// General API rate limiter (per IP)
export const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: {
    success: false,
    error: 'Too many requests from this IP, please try again later.'
  },
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
});

// Stricter rate limiter for authentication endpoints (prevent brute force)
export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // Limit each IP to 5 login attempts per 15 minutes
  message: {
    success: false,
    error: 'Too many login attempts, please try again later.'
  },
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: true, // Don't count successful requests
});

// Rate limiter for write operations (POST, PUT, DELETE)
export const writeLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 30, // Limit each IP to 30 write operations per minute
  message: {
    success: false,
    error: 'Too many write operations, please slow down.'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Rate limiter for read operations (GET)
// Increased limit for testing - can be reduced in production
export const readLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 500, // Limit each IP to 500 read operations per minute (increased for testing)
  message: {
    success: false,
    error: 'Too many read requests, please try again later.'
  },
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
  // Custom handler to add Retry-After header
  handler: (req, res) => {
    const resetTime = Math.ceil((req.rateLimit.resetTime - Date.now()) / 1000);
    res.setHeader('Retry-After', resetTime.toString());
    res.status(429).json({
      success: false,
      error: 'Too many read requests, please try again later.',
      retryAfter: resetTime
    });
  },
  // Skip rate limiting for localhost during development
  skip: (req) => {
    const ip = req.ip || req.connection.remoteAddress || '';
    return ip === '127.0.0.1' || ip === '::1' || ip.includes('localhost');
  },
});

// Lenient rate limiter for health checks
export const healthLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 60, // Allow 60 health checks per minute
  message: {
    success: false,
    error: 'Too many health check requests, please try again later.'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

