import express from 'express';
import { body, query } from 'express-validator';
import {
  getAllExams,
  getExamById,
  createExam,
  updateExam,
  deleteExam,
  getTeacherExams,
  getStudentExams,
  updateExamStatus,
  assignStudentToExam,
  unassignStudentFromExam,
  getStudentsAssignedToExam
} from '../controllers/exam.controller.js';

const router = express.Router();

// Get all exams (with optional filters)
router.get('/', 
  [
    query('page').optional().isInt({ min: 0 }),
    query('limit').optional().isInt({ min: 1, max: 100 }),
    query('teacherId').optional().isMongoId(),
    query('studentId').optional().isMongoId()
  ],
  getAllExams
);

// Get teacher's exams
router.get('/teacher/:teacherId',
  [
    query('page').optional().isInt({ min: 0 }),
    query('limit').optional().isInt({ min: 1, max: 100 })
  ],
  getTeacherExams
);

// Get student's assigned exams
router.get('/student/:studentId',
  [
    query('page').optional().isInt({ min: 0 }),
    query('limit').optional().isInt({ min: 1, max: 100 })
  ],
  getStudentExams
);

// Get exam by ID
router.get('/:id', getExamById);

// Create new exam
router.post('/',
  [
    body('title').notEmpty().withMessage('Title is required'),
    body('subject').notEmpty().withMessage('Subject is required'),
    body('examDate').notEmpty().withMessage('Exam date is required'),
    body('duration').isInt({ min: 1 }).withMessage('Duration must be a positive integer'),
    body('createdBy').isMongoId().withMessage('CreatedBy must be a valid ObjectId')
  ],
  createExam
);

// Update exam
router.put('/:id',
  [
    body('title').optional().notEmpty(),
    body('examDate').optional().notEmpty(),
    body('duration').optional().isInt({ min: 1 })
  ],
  updateExam
);

// Update exam status
router.patch('/:id/status',
  [
    body('status').isIn(['scheduled', 'delayed', 'cancelled', 'completed']).withMessage('Invalid status')
  ],
  updateExamStatus
);

// Assign student to exam
router.post('/:id/assign/:studentId', assignStudentToExam);

// Unassign student from exam
router.delete('/:id/assign/:studentId', unassignStudentFromExam);

// Get students assigned to exam
router.get('/:id/students', getStudentsAssignedToExam);

// Delete exam
router.delete('/:id', deleteExam);

export default router;

