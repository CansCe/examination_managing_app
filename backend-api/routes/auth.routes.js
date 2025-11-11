import express from 'express';
import { body } from 'express-validator';
import { login, getCurrentUser, changePassword } from '../controllers/auth.controller.js';
import { authLimiter, readLimiter, writeLimiter } from '../middleware/rateLimiter.js';

const router = express.Router();

// Login endpoint - strict rate limiting to prevent brute force
router.post('/login', 
  authLimiter,
  [
    body('username').notEmpty().withMessage('Username is required'),
    body('password').notEmpty().withMessage('Password is required')
  ],
  login
);

// Get current user - read rate limiting
router.get('/user/:userId', readLimiter, getCurrentUser);

// Change password - write rate limiting
router.put('/password',
  writeLimiter,
  [
    body('userId').notEmpty().withMessage('User ID is required'),
    body('currentPassword').notEmpty().withMessage('Current password is required'),
    body('newPassword').isLength({ min: 6 }).withMessage('New password must be at least 6 characters')
  ],
  changePassword
);

export default router;

