import express from 'express';
import { query } from 'express-validator';
import {
  getAllTeachers,
  getTeacherById,
  createTeacher,
  updateTeacher,
  deleteTeacher
} from '../controllers/teacher.controller.js';

const router = express.Router();

router.get('/',
  [
    query('page').optional().isInt({ min: 0 }),
    query('limit').optional().isInt({ min: 1, max: 100 })
  ],
  getAllTeachers
);

router.get('/:id', getTeacherById);
router.post('/', createTeacher);
router.put('/:id', updateTeacher);
router.delete('/:id', deleteTeacher);

export default router;

