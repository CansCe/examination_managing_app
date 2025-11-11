import express from 'express';
import { body, query } from 'express-validator';
import {
  getAllQuestions,
  getQuestionById,
  createQuestion,
  updateQuestion,
  deleteQuestion,
  getQuestionsByIds
} from '../controllers/question.controller.js';
import { readLimiter, writeLimiter } from '../middleware/rateLimiter.js';

const router = express.Router();

router.get('/',
  readLimiter,
  [
    query('page').optional().isInt({ min: 0 }),
    query('limit').optional().isInt({ min: 1, max: 100 }),
    query('ids').optional().isString()
  ],
  getAllQuestions
);

router.get('/ids', readLimiter, getQuestionsByIds);
router.get('/:id', readLimiter, getQuestionById);
router.post('/',
  writeLimiter,
  [
    body('text').notEmpty().withMessage('Question text is required'),
    body('type').isIn(['multiple-choice', 'true-false', 'short-answer']).withMessage('Invalid question type'),
    body('correctAnswer').notEmpty().withMessage('Correct answer is required')
  ],
  createQuestion
);
router.put('/:id', writeLimiter, updateQuestion);
router.delete('/:id', writeLimiter, deleteQuestion);

export default router;

