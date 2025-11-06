import express from 'express';
import { body, query } from 'express-validator';
import {
  getAllStudents,
  getStudentById,
  createStudent,
  updateStudent,
  deleteStudent
} from '../controllers/student.controller.js';

const router = express.Router();

router.get('/',
  [
    query('page').optional().isInt({ min: 0 }),
    query('limit').optional().isInt({ min: 1, max: 100 })
  ],
  getAllStudents
);

router.get('/:id', getStudentById);
router.post('/', 
  [
    body('fullName').notEmpty().withMessage('Full name is required'),
    body('email').isEmail().withMessage('Valid email is required'),
    body('studentId').notEmpty().withMessage('Student ID is required')
  ],
  createStudent
);
router.put('/:id', updateStudent);
router.delete('/:id', deleteStudent);

export default router;

