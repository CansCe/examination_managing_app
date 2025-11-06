import { getDatabase } from '../config/database.js';
import { ObjectId } from 'mongodb';
import { validationResult } from 'express-validator';

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

    let student;
    try {
      student = await db.collection('students').findOne({ _id: new ObjectId(id) });
    } catch (error) {
      return res.status(400).json({ success: false, error: 'Invalid student ID' });
    }

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
    const studentData = {
      ...req.body,
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

    const updateData = {
      ...req.body,
      updatedAt: new Date().toISOString()
    };

    if (updateData.assignedExams) {
      updateData.assignedExams = updateData.assignedExams.map(id => 
        typeof id === 'string' ? new ObjectId(id) : id
      );
    }

    const result = await db.collection('students').updateOne(
      { _id: new ObjectId(id) },
      { $set: updateData }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ success: false, error: 'Student not found' });
    }

    const updatedStudent = await db.collection('students').findOne({ _id: new ObjectId(id) });

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

    const result = await db.collection('students').deleteOne({ _id: new ObjectId(id) });

    if (result.deletedCount === 0) {
      return res.status(404).json({ success: false, error: 'Student not found' });
    }

    res.json({ success: true, message: 'Student deleted successfully' });
  } catch (error) {
    console.error('Delete student error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

