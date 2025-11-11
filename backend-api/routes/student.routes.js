import express from 'express';
import { body, query } from 'express-validator';
import {
  getAllStudents,
  getStudentById,
  createStudent,
  updateStudent,
  deleteStudent
} from '../controllers/student.controller.js';
import { readLimiter, writeLimiter } from '../middleware/rateLimiter.js';

const router = express.Router();

router.get('/',
  readLimiter,
  [
    query('page').optional().isInt({ min: 0 }),
    query('limit').optional().isInt({ min: 1, max: 100 })
  ],
  getAllStudents
);

router.get('/:id', readLimiter, getStudentById);
router.post('/', 
  writeLimiter,
  [
    body('fullName').notEmpty().withMessage('Full name is required'),
    body('email').isEmail().withMessage('Valid email is required'),
    body('studentId').optional().notEmpty().withMessage('Student ID cannot be empty if provided'),
    body('rollNumber').optional().notEmpty().withMessage('Roll number cannot be empty if provided'),
    // At least one of studentId or rollNumber must be provided
    body().custom((value) => {
      if (!value.studentId && !value.rollNumber) {
        throw new Error('Either studentId or rollNumber is required');
      }
      return true;
    })
  ],
  createStudent
);
router.put('/:id', writeLimiter, updateStudent);
router.delete('/:id', writeLimiter, deleteStudent);

export default router;

