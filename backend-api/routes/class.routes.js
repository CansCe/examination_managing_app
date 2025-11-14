import express from 'express';
import { body, query } from 'express-validator';
import {
  getAllClasses,
  getClassById,
  getClassByName,
  getClassStudents,
  createClass,
  updateClass,
  deleteClass,
  addStudentToClass,
  removeStudentFromClass
} from '../controllers/class.controller.js';
import { readLimiter, writeLimiter } from '../middleware/rateLimiter.js';

const router = express.Router();

// Get all classes (with optional filters)
router.get('/',
  readLimiter,
  [
    query('page').optional().isInt({ min: 0 }),
    query('limit').optional().isInt({ min: 1, max: 100 }),
    query('teacherId').optional().isMongoId(),
    query('subject').optional().isString()
  ],
  getAllClasses
);

// Get class by name
router.get('/name/:className', readLimiter, getClassByName);

// Get students in a class
router.get('/:id/students',
  readLimiter,
  [
    query('page').optional().isInt({ min: 0 }),
    query('limit').optional().isInt({ min: 1, max: 100 })
  ],
  getClassStudents
);

// Get class by ID
router.get('/:id', readLimiter, getClassById);

// Create a new class
router.post('/',
  writeLimiter,
  [
    body('className').notEmpty().withMessage('Class name is required'),
    body('subject').optional().isString(),
    body('teacher').optional().isMongoId(),
    body('studentList').optional().isArray()
  ],
  createClass
);

// Update class
router.put('/:id', writeLimiter, updateClass);

// Delete class
router.delete('/:id', writeLimiter, deleteClass);

// Add student to class
router.post('/:id/students',
  writeLimiter,
  [
    body('studentId').isMongoId().withMessage('Valid student ID is required')
  ],
  addStudentToClass
);

// Remove student from class
router.delete('/:id/students/:studentId', writeLimiter, removeStudentFromClass);

export default router;

