import express from 'express';
import { body } from 'express-validator';
import { login, getCurrentUser, changePassword } from '../controllers/auth.controller.js';

const router = express.Router();

// Login endpoint
router.post('/login', 
  [
    body('username').notEmpty().withMessage('Username is required'),
    body('password').notEmpty().withMessage('Password is required')
  ],
  login
);

// Get current user
router.get('/user/:userId', getCurrentUser);

// Change password
router.put('/password',
  [
    body('userId').notEmpty().withMessage('User ID is required'),
    body('currentPassword').notEmpty().withMessage('Current password is required'),
    body('newPassword').isLength({ min: 6 }).withMessage('New password must be at least 6 characters')
  ],
  changePassword
);

export default router;

