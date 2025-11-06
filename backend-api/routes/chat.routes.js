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
  getDefaultAdmin
} from '../controllers/chat.controller.js';

const router = express.Router();

router.post('/student',
  [
    body('fromUserId').isMongoId().withMessage('Valid from user ID is required'),
    body('toUserId').isMongoId().withMessage('Valid to user ID is required'),
    body('message').notEmpty().withMessage('Message is required')
  ],
  sendStudentMessage
);

router.post('/teacher',
  [
    body('fromUserId').isMongoId().withMessage('Valid from user ID is required'),
    body('toUserId').isMongoId().withMessage('Valid to user ID is required'),
    body('message').notEmpty().withMessage('Message is required')
  ],
  sendTeacherMessage
);

router.post('/admin',
  [
    body('fromUserId').isMongoId().withMessage('Valid from user ID is required'),
    body('toUserId').isMongoId().withMessage('Valid to user ID is required'),
    body('message').notEmpty().withMessage('Message is required')
  ],
  sendAdminMessage
);

router.get('/conversation', getConversation);
router.get('/conversations', getAllConversations);
router.get('/unread', getUnreadMessages);
router.get('/default-admin', getDefaultAdmin);
router.put('/read/:studentId', markAsRead);

export default router;

