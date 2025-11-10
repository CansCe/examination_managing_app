import { getDatabase } from '../config/database.js';
import { ObjectId } from 'mongodb';
import { validationResult } from 'express-validator';

// Helper function to validate ObjectId
function isValidObjectId(id) {
  try {
    return ObjectId.isValid(id) && new ObjectId(id).toString() === id;
  } catch {
    return false;
  }
}

export const getAllExams = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const db = getDatabase();
    const page = parseInt(req.query.page || '0');
    const limit = parseInt(req.query.limit || '20');
    const skip = page * limit;

    let query = {};

    // Filter by teacher if provided
    if (req.query.teacherId) {
      if (!isValidObjectId(req.query.teacherId)) {
        return res.status(400).json({ success: false, error: 'Invalid teacher ID' });
      }
      query.createdBy = new ObjectId(req.query.teacherId);
    }

    const exams = await db.collection('exams')
      .find(query)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .toArray();

    const total = await db.collection('exams').countDocuments(query);

    res.json({
      success: true,
      data: exams,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    console.error('Get all exams error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getExamById = async (req, res) => {
  try {
    const { id } = req.params;
    const db = getDatabase();

    if (!isValidObjectId(id)) {
      return res.status(400).json({ success: false, error: 'Invalid exam ID' });
    }

    const exam = await db.collection('exams').findOne({ _id: new ObjectId(id) });

    if (!exam) {
      return res.status(404).json({ success: false, error: 'Exam not found' });
    }

    // Populate questions if exam has question IDs
    if (exam.questions && Array.isArray(exam.questions) && exam.questions.length > 0) {
      const questionIds = exam.questions.map(q => new ObjectId(q));
      const questions = await db.collection('questions')
        .find({ _id: { $in: questionIds } })
        .toArray();
      
      exam.populatedQuestions = questions;
    }

    res.json({ success: true, data: exam });
  } catch (error) {
    console.error('Get exam by ID error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const createExam = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const db = getDatabase();
    const { questions, ...examData } = req.body;

    // Validate createdBy is a valid ObjectId
    if (examData.createdBy && !isValidObjectId(examData.createdBy)) {
      return res.status(400).json({ success: false, error: 'Invalid createdBy ID' });
    }

    const examInsert = {
      title: examData.title,
      subject: examData.subject,
      examDate: examData.examDate || examData.exam_date ? new Date(examData.examDate || examData.exam_date) : new Date(),
      duration: examData.duration,
      status: examData.status || 'scheduled',
      createdBy: examData.createdBy ? new ObjectId(examData.createdBy) : null,
      questions: questions && Array.isArray(questions) 
        ? questions.filter(q => isValidObjectId(q)).map(q => new ObjectId(q))
        : [],
      createdAt: new Date(),
      updatedAt: new Date()
    };

    const result = await db.collection('exams').insertOne(examInsert);
    const exam = await db.collection('exams').findOne({ _id: result.insertedId });

    res.status(201).json({
      success: true,
      data: exam,
      insertedId: exam._id.toString()
    });
  } catch (error) {
    console.error('Create exam error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const updateExam = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { id } = req.params;
    const db = getDatabase();

    if (!isValidObjectId(id)) {
      return res.status(400).json({ success: false, error: 'Invalid exam ID' });
    }

    const { questions, ...updateData } = req.body;

    const examUpdate = {
      updatedAt: new Date()
    };

    if (updateData.title) examUpdate.title = updateData.title;
    if (updateData.subject) examUpdate.subject = updateData.subject;
    if (updateData.examDate || updateData.exam_date) {
      examUpdate.examDate = new Date(updateData.examDate || updateData.exam_date);
    }
    if (updateData.duration) examUpdate.duration = updateData.duration;
    if (updateData.status) examUpdate.status = updateData.status;
    if (updateData.createdBy || updateData.created_by) {
      const createdBy = updateData.createdBy || updateData.created_by;
      if (!isValidObjectId(createdBy)) {
        return res.status(400).json({ success: false, error: 'Invalid createdBy ID' });
      }
      examUpdate.createdBy = new ObjectId(createdBy);
    }

    // Update questions if provided
    if (questions && Array.isArray(questions)) {
      examUpdate.questions = questions
        .filter(q => isValidObjectId(q))
        .map(q => new ObjectId(q));
    }

    const result = await db.collection('exams').updateOne(
      { _id: new ObjectId(id) },
      { $set: examUpdate }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ success: false, error: 'Exam not found' });
    }

    const updatedExam = await db.collection('exams').findOne({ _id: new ObjectId(id) });

    res.json({ success: true, data: updatedExam });
  } catch (error) {
    console.error('Update exam error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const updateExamStatus = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { id } = req.params;
    const { status, newDate } = req.body;
    const db = getDatabase();

    if (!isValidObjectId(id)) {
      return res.status(400).json({ success: false, error: 'Invalid exam ID' });
    }

    const updateData = {
      status,
      updatedAt: new Date()
    };

    // If status is delayed and newDate is provided, update the date
    if (status === 'delayed' && newDate) {
      updateData.examDate = new Date(newDate);
    }

    const result = await db.collection('exams').updateOne(
      { _id: new ObjectId(id) },
      { $set: updateData }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ success: false, error: 'Exam not found' });
    }

    const updatedExam = await db.collection('exams').findOne({ _id: new ObjectId(id) });

    res.json({ success: true, message: 'Exam status updated', data: updatedExam });
  } catch (error) {
    console.error('Update exam status error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const deleteExam = async (req, res) => {
  try {
    const { id } = req.params;
    const db = getDatabase();

    if (!isValidObjectId(id)) {
      return res.status(400).json({ success: false, error: 'Invalid exam ID' });
    }

    const examObjectId = new ObjectId(id);

    // Delete the exam
    const result = await db.collection('exams').deleteOne({ _id: examObjectId });

    if (result.deletedCount === 0) {
      return res.status(404).json({ success: false, error: 'Exam not found' });
    }

    // Clean up related data: Remove exam from student_exams collection
    const studentExamsResult = await db.collection('student_exams').deleteMany({ 
      examId: examObjectId 
    });
    console.log(`Deleted ${studentExamsResult.deletedCount} student exam assignments`);

    // Also remove exam from students' assignedExams arrays
    const studentsUpdateResult = await db.collection('students').updateMany(
      { assignedExams: examObjectId },
      { $pull: { assignedExams: examObjectId } }
    );
    console.log(`Removed exam from ${studentsUpdateResult.modifiedCount} students' assignedExams arrays`);

    res.json({ 
      success: true, 
      message: 'Exam deleted successfully',
      deletedAssignments: studentExamsResult.deletedCount,
      updatedStudents: studentsUpdateResult.modifiedCount
    });
  } catch (error) {
    console.error('Delete exam error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getTeacherExams = async (req, res) => {
  try {
    const { teacherId } = req.params;
    const page = parseInt(req.query.page || '0');
    const limit = parseInt(req.query.limit || '20');
    const skip = page * limit;

    const db = getDatabase();

    if (!isValidObjectId(teacherId)) {
      return res.status(400).json({ success: false, error: 'Invalid teacher ID' });
    }

    const exams = await db.collection('exams')
      .find({ createdBy: new ObjectId(teacherId) })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .toArray();

    const total = await db.collection('exams').countDocuments({ createdBy: new ObjectId(teacherId) });

    res.json({
      success: true,
      data: exams,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    console.error('Get teacher exams error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getStudentExams = async (req, res) => {
  try {
    const { studentId } = req.params;
    const page = parseInt(req.query.page || '0');
    const limit = parseInt(req.query.limit || '20');
    const skip = page * limit;

    const db = getDatabase();

    if (!isValidObjectId(studentId)) {
      return res.status(400).json({ success: false, error: 'Invalid student ID' });
    }

    // Get student's assigned exams from student_exams collection
    const studentExams = await db.collection('student_exams')
      .find({ studentId: new ObjectId(studentId) })
      .toArray();

    const examIds = studentExams.map(se => se.examId);

    if (examIds.length === 0) {
      return res.json({
        success: true,
        data: [],
        pagination: { page, limit, total: 0, pages: 0 }
      });
    }

    const exams = await db.collection('exams')
      .find({ _id: { $in: examIds } })
      .sort({ examDate: -1 })
      .skip(skip)
      .limit(limit)
      .toArray();

    const total = examIds.length;

    res.json({
      success: true,
      data: exams,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    console.error('Get student exams error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const assignStudentToExam = async (req, res) => {
  try {
    const { id: examId, studentId } = req.params;
    const db = getDatabase();

    if (!isValidObjectId(examId) || !isValidObjectId(studentId)) {
      return res.status(400).json({ success: false, error: 'Invalid exam or student ID' });
    }

    // Verify exam exists
    const exam = await db.collection('exams').findOne({ _id: new ObjectId(examId) });

    if (!exam) {
      return res.status(404).json({ success: false, error: 'Exam not found' });
    }

    // Check if already assigned
    const existing = await db.collection('student_exams').findOne({
      studentId: new ObjectId(studentId),
      examId: new ObjectId(examId)
    });

    if (existing) {
      return res.json({ success: true, message: 'Student already assigned to exam' });
    }

    // Assign student to exam
    await db.collection('student_exams').insertOne({
      studentId: new ObjectId(studentId),
      examId: new ObjectId(examId),
      assignedAt: new Date()
    });

    res.json({ success: true, message: 'Student assigned to exam successfully' });
  } catch (error) {
    console.error('Assign student to exam error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const unassignStudentFromExam = async (req, res) => {
  try {
    const { id: examId, studentId } = req.params;
    const db = getDatabase();

    if (!isValidObjectId(examId) || !isValidObjectId(studentId)) {
      return res.status(400).json({ success: false, error: 'Invalid exam or student ID' });
    }

    const result = await db.collection('student_exams').deleteOne({
      studentId: new ObjectId(studentId),
      examId: new ObjectId(examId)
    });

    if (result.deletedCount === 0) {
      return res.status(404).json({ success: false, error: 'Assignment not found' });
    }

    res.json({ success: true, message: 'Student unassigned from exam successfully' });
  } catch (error) {
    console.error('Unassign student from exam error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getStudentsAssignedToExam = async (req, res) => {
  try {
    const { id: examId } = req.params;
    const db = getDatabase();

    if (!isValidObjectId(examId)) {
      return res.status(400).json({ success: false, error: 'Invalid exam ID' });
    }

    const studentExams = await db.collection('student_exams')
      .find({ examId: new ObjectId(examId) })
      .toArray();

    const studentIds = studentExams.map(se => se.studentId);

    if (studentIds.length === 0) {
      return res.json({ success: true, data: [] });
    }

    const students = await db.collection('students')
      .find({ _id: { $in: studentIds } })
      .toArray();

    res.json({ success: true, data: students });
  } catch (error) {
    console.error('Get students assigned to exam error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};
