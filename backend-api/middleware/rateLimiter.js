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
export const readLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 60, // Limit each IP to 60 read operations per minute
  message: {
    success: false,
    error: 'Too many read requests, please try again later.'
  },
  standardHeaders: true,
  legacyHeaders: false,
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

