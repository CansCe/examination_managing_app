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

const router = express.Router();

router.get('/',
  [
    query('page').optional().isInt({ min: 0 }),
    query('limit').optional().isInt({ min: 1, max: 100 }),
    query('ids').optional().isString()
  ],
  getAllQuestions
);

router.get('/ids', getQuestionsByIds);
router.get('/:id', getQuestionById);
router.post('/',
  [
    body('text').notEmpty().withMessage('Question text is required'),
    body('type').isIn(['multiple-choice', 'true-false', 'short-answer']).withMessage('Invalid question type'),
    body('correctAnswer').notEmpty().withMessage('Correct answer is required')
  ],
  createQuestion
);
router.put('/:id', updateQuestion);
router.delete('/:id', deleteQuestion);

export default router;

