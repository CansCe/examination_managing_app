import express from 'express';
import { body } from 'express-validator';
import {
  submitExamAnswers,
  getExamResult,
  getStudentResults,
  getExamResults
} from '../controllers/examResult.controller.js';
import { readLimiter, writeLimiter } from '../middleware/rateLimiter.js';

const router = express.Router();

router.post('/submit',
  writeLimiter,
  [
    body('examId').isMongoId().withMessage('Valid exam ID is required'),
    body('studentId').isMongoId().withMessage('Valid student ID is required'),
    body('answers').isObject().withMessage('Answers must be an object'),
    body('questions').isArray().withMessage('Questions array is required')
  ],
  submitExamAnswers
);

router.get('/exam/:examId/student/:studentId', readLimiter, getExamResult);
router.get('/student/:studentId', readLimiter, getStudentResults);
router.get('/exam/:examId', readLimiter, getExamResults);

export default router;

