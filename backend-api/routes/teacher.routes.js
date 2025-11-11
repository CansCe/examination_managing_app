import express from 'express';
import { query } from 'express-validator';
import {
  getAllTeachers,
  getTeacherById,
  createTeacher,
  updateTeacher,
  deleteTeacher
} from '../controllers/teacher.controller.js';
import { readLimiter, writeLimiter } from '../middleware/rateLimiter.js';

const router = express.Router();

router.get('/',
  readLimiter,
  [
    query('page').optional().isInt({ min: 0 }),
    query('limit').optional().isInt({ min: 1, max: 100 })
  ],
  getAllTeachers
);

router.get('/:id', readLimiter, getTeacherById);
router.post('/', writeLimiter, createTeacher);
router.put('/:id', writeLimiter, updateTeacher);
router.delete('/:id', writeLimiter, deleteTeacher);

export default router;

