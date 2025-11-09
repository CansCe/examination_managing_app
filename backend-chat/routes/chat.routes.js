import express from 'express';
import { body } from 'express-validator';
import {
  sendStudentMessage,
  sendTeacherMessage,
  sendAdminMessage,
  getConversation,
  markAsRead,
  getAllConversations,
  getUnreadMessages,
  getUnreadCount,
  getDefaultAdmin,
  closeConversation,
  createOrUpdateConversation,
  getConversationMetadata
} from '../controllers/chat.controller.js';
import { apiLimiter, unreadLimiter, messageLimiter } from '../middleware/rateLimiter.js';

const router = express.Router();

// SECURITY: Apply rate limiting to message sending endpoints
router.post('/student',
  messageLimiter, // Rate limit: 20 messages per minute per IP
  [
    body('fromUserId').notEmpty().withMessage('fromUserId is required'),
    body('toUserId').notEmpty().withMessage('toUserId is required'),
    body('message').notEmpty().withMessage('Message is required'),
    body('message').isLength({ max: 5000 }).withMessage('Message too long (max 5000 characters)')
  ],
  sendStudentMessage
);

router.post('/teacher',
  messageLimiter, // Rate limit: 20 messages per minute per IP
  [
    body('fromUserId').notEmpty().withMessage('fromUserId is required'),
    body('toUserId').notEmpty().withMessage('toUserId is required'),
    body('message').notEmpty().withMessage('Message is required'),
    body('message').isLength({ max: 5000 }).withMessage('Message too long (max 5000 characters)')
  ],
  sendTeacherMessage
);

router.post('/admin',
  messageLimiter, // Rate limit: 20 messages per minute per IP
  [
    body('fromUserId').notEmpty().withMessage('fromUserId is required'),
    body('toUserId').notEmpty().withMessage('toUserId is required'),
    body('message').notEmpty().withMessage('Message is required'),
    body('message').isLength({ max: 5000 }).withMessage('Message too long (max 5000 characters)')
  ],
  sendAdminMessage
);

// SECURITY: Apply rate limiting to all endpoints
router.get('/conversation', apiLimiter, getConversation);
router.get('/conversations', apiLimiter, getAllConversations);
router.get('/unread', unreadLimiter, getUnreadMessages); // Stricter rate limit: 30 requests per minute
router.get('/unread/count', unreadLimiter, getUnreadCount); // Stricter rate limit: 30 requests per minute
router.get('/default-admin', apiLimiter, getDefaultAdmin);
router.get('/conversation/:userId/:targetUserId/metadata', apiLimiter, getConversationMetadata);
router.post('/conversation', apiLimiter, createOrUpdateConversation);
router.delete('/conversation/:userId/:targetUserId', apiLimiter, closeConversation);
router.put('/read/:studentId', apiLimiter, markAsRead);

export default router;

