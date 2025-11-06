import express from 'express';
import { body } from 'express-validator';
import {
  submitExamAnswers,
  getExamResult,
  getStudentResults,
  getExamResults
} from '../controllers/examResult.controller.js';

const router = express.Router();

router.post('/submit',
  [
    body('examId').isMongoId().withMessage('Valid exam ID is required'),
    body('studentId').isMongoId().withMessage('Valid student ID is required'),
    body('answers').isObject().withMessage('Answers must be an object'),
    body('questions').isArray().withMessage('Questions array is required')
  ],
  submitExamAnswers
);

router.get('/exam/:examId/student/:studentId', getExamResult);
router.get('/student/:studentId', getStudentResults);
router.get('/exam/:examId', getExamResults);

export default router;

