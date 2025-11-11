import { getDatabase } from '../config/database.js';
import { ObjectId } from 'mongodb';
import { validationResult } from 'express-validator';
import { sanitizeObjectId, sanitizeQuery } from '../utils/inputSanitizer.js';

export const getAllStudents = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const db = getDatabase();
    const page = parseInt(req.query.page || '0');
    const limit = parseInt(req.query.limit || '20');
    const skip = page * limit;

    const students = await db.collection('students')
      .find({})
      .skip(skip)
      .limit(limit)
      .toArray();

    const total = await db.collection('students').countDocuments({});

    res.json({
      success: true,
      data: students,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    console.error('Get all students error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getStudentById = async (req, res) => {
  try {
    const { id } = req.params;
    const db = getDatabase();

    // SECURITY: Sanitize user ID to prevent NoSQL injection
    let sanitizedId;
    try {
      sanitizedId = sanitizeObjectId(id);
    } catch (error) {
      return res.status(400).json({ success: false, error: 'Invalid student ID format' });
    }

    const student = await db.collection('students').findOne({ _id: sanitizedId });

    if (!student) {
      return res.status(404).json({ success: false, error: 'Student not found' });
    }

    res.json({ success: true, data: student });
  } catch (error) {
    console.error('Get student by ID error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const createStudent = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const db = getDatabase();
    
    // Handle both studentId and rollNumber - use studentId as rollNumber if rollNumber not provided
    const rollNumber = req.body.rollNumber || req.body.studentId || '';
    
    const studentData = {
      ...req.body,
      rollNumber: rollNumber, // Ensure rollNumber is set
      studentId: req.body.studentId || rollNumber, // Ensure studentId is set
      _id: new ObjectId(),
      assignedExams: req.body.assignedExams?.map(id => 
        typeof id === 'string' ? new ObjectId(id) : id
      ) || [],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    const result = await db.collection('students').insertOne(studentData);

    res.status(201).json({
      success: true,
      data: studentData,
      insertedId: result.insertedId.toString()
    });
  } catch (error) {
    console.error('Create student error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const updateStudent = async (req, res) => {
  try {
    const { id } = req.params;
    const db = getDatabase();

    // SECURITY: Sanitize user ID to prevent NoSQL injection
    let sanitizedId;
    try {
      sanitizedId = sanitizeObjectId(id);
    } catch (error) {
      return res.status(400).json({ success: false, error: 'Invalid student ID format' });
    }

    // SECURITY: Sanitize update data to prevent NoSQL injection
    const sanitizedBody = sanitizeQuery(req.body);
    const updateData = {
      ...sanitizedBody,
      updatedAt: new Date().toISOString()
    };

    // Remove MongoDB operators if any
    delete updateData._id;
    delete updateData.$set;
    delete updateData.$unset;
    delete updateData.$inc;
    delete updateData.$push;
    delete updateData.$pull;

    if (updateData.assignedExams && Array.isArray(updateData.assignedExams)) {
      updateData.assignedExams = updateData.assignedExams.map(examId => {
        try {
          return sanitizeObjectId(examId);
        } catch {
          return null;
        }
      }).filter(id => id !== null);
    }

    const result = await db.collection('students').updateOne(
      { _id: sanitizedId },
      { $set: updateData }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ success: false, error: 'Student not found' });
    }

    const updatedStudent = await db.collection('students').findOne({ _id: sanitizedId });

    res.json({ success: true, data: updatedStudent });
  } catch (error) {
    console.error('Update student error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const deleteStudent = async (req, res) => {
  try {
    const { id } = req.params;
    const db = getDatabase();

    // SECURITY: Sanitize user ID to prevent NoSQL injection
    let sanitizedId;
    try {
      sanitizedId = sanitizeObjectId(id);
    } catch (error) {
      return res.status(400).json({ success: false, error: 'Invalid student ID format' });
    }

    const result = await db.collection('students').deleteOne({ _id: sanitizedId });

    if (result.deletedCount === 0) {
      return res.status(404).json({ success: false, error: 'Student not found' });
    }

    res.json({ success: true, message: 'Student deleted successfully' });
  } catch (error) {
    console.error('Delete student error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

