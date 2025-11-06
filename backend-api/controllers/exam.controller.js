import { getDatabase } from '../config/database.js';
import { ObjectId } from 'mongodb';
import { validationResult } from 'express-validator';

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
      query.createdBy = new ObjectId(req.query.teacherId);
    }

    const exams = await db.collection('exams')
      .find(query)
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

    let exam;
    try {
      exam = await db.collection('exams').findOne({ _id: new ObjectId(id) });
    } catch (error) {
      return res.status(400).json({ success: false, error: 'Invalid exam ID' });
    }

    if (!exam) {
      return res.status(404).json({ success: false, error: 'Exam not found' });
    }

    // Populate questions if they exist
    if (exam.questions && exam.questions.length > 0) {
      const questionIds = exam.questions.map(q => 
        typeof q === 'string' ? new ObjectId(q) : q
      );
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
    const examData = {
      ...req.body,
      _id: new ObjectId(),
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      status: req.body.status || 'scheduled',
      questions: req.body.questions?.map(q => 
        typeof q === 'string' ? new ObjectId(q) : q
      ) || [],
      createdBy: new ObjectId(req.body.createdBy)
    };

    // Convert examDate if it's a string
    if (typeof examData.examDate === 'string') {
      examData.examDate = new Date(examData.examDate);
    }

    const result = await db.collection('exams').insertOne(examData);

    res.status(201).json({
      success: true,
      data: examData,
      insertedId: result.insertedId.toString()
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

    const updateData = {
      ...req.body,
      updatedAt: new Date().toISOString()
    };

    // Convert dates if provided as strings
    if (updateData.examDate && typeof updateData.examDate === 'string') {
      updateData.examDate = new Date(updateData.examDate);
    }

    // Convert ObjectIds if needed
    if (updateData.createdBy) {
      updateData.createdBy = new ObjectId(updateData.createdBy);
    }
    if (updateData.questions) {
      updateData.questions = updateData.questions.map(q => 
        typeof q === 'string' ? new ObjectId(q) : q
      );
    }

    const result = await db.collection('exams').updateOne(
      { _id: new ObjectId(id) },
      { $set: updateData }
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
    const { status } = req.body;
    const db = getDatabase();

    const updateData = {
      status,
      updatedAt: new Date().toISOString()
    };

    // If status is delayed and newDate is provided, update the date
    if (status === 'delayed' && req.body.newDate) {
      updateData.examDate = new Date(req.body.newDate);
    }

    const result = await db.collection('exams').updateOne(
      { _id: new ObjectId(id) },
      { $set: updateData }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ success: false, error: 'Exam not found' });
    }

    res.json({ success: true, message: 'Exam status updated' });
  } catch (error) {
    console.error('Update exam status error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const deleteExam = async (req, res) => {
  try {
    const { id } = req.params;
    const db = getDatabase();

    const result = await db.collection('exams').deleteOne({ _id: new ObjectId(id) });

    if (result.deletedCount === 0) {
      return res.status(404).json({ success: false, error: 'Exam not found' });
    }

    res.json({ success: true, message: 'Exam deleted successfully' });
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

    // Get teacher's created exams
    const teacher = await db.collection('teachers').findOne({ 
      _id: new ObjectId(teacherId) 
    });

    if (!teacher) {
      return res.status(404).json({ success: false, error: 'Teacher not found' });
    }

    const examIds = (teacher.createdExams || []).map(id => 
      typeof id === 'string' ? new ObjectId(id) : id
    );

    const exams = await db.collection('exams')
      .find({ _id: { $in: examIds } })
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

    // Get student's assigned exams
    const student = await db.collection('students').findOne({ 
      _id: new ObjectId(studentId) 
    });

    if (!student) {
      return res.status(404).json({ success: false, error: 'Student not found' });
    }

    const examIds = (student.assignedExams || []).map(id => 
      typeof id === 'string' ? new ObjectId(id) : id
    );

    const exams = await db.collection('exams')
      .find({ _id: { $in: examIds } })
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

    // Verify exam exists
    const exam = await db.collection('exams').findOne({ _id: new ObjectId(examId) });
    if (!exam) {
      return res.status(404).json({ success: false, error: 'Exam not found' });
    }

    // Get student and add exam to assignedExams
    const student = await db.collection('students').findOne({ 
      _id: new ObjectId(studentId) 
    });

    if (!student) {
      return res.status(404).json({ success: false, error: 'Student not found' });
    }

    const assignedExams = (student.assignedExams || []).map(id => 
      typeof id === 'string' ? new ObjectId(id) : id
    );

    const examObjectId = new ObjectId(examId);
    if (assignedExams.some(id => id.toString() === examObjectId.toString())) {
      return res.json({ success: true, message: 'Student already assigned to exam' });
    }

    assignedExams.push(examObjectId);

    await db.collection('students').updateOne(
      { _id: new ObjectId(studentId) },
      { $set: { assignedExams, updatedAt: new Date().toISOString() } }
    );

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

    const student = await db.collection('students').findOne({ 
      _id: new ObjectId(studentId) 
    });

    if (!student) {
      return res.status(404).json({ success: false, error: 'Student not found' });
    }

    const assignedExams = (student.assignedExams || [])
      .map(id => typeof id === 'string' ? new ObjectId(id) : id)
      .filter(id => id.toString() !== examId);

    await db.collection('students').updateOne(
      { _id: new ObjectId(studentId) },
      { $set: { assignedExams, updatedAt: new Date().toISOString() } }
    );

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

    const students = await db.collection('students')
      .find({ 
        assignedExams: { $in: [new ObjectId(examId)] } 
      })
      .toArray();

    res.json({ success: true, data: students });
  } catch (error) {
    console.error('Get students assigned to exam error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

