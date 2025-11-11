import { getDatabase } from '../config/database.js';
import { ObjectId } from 'mongodb';
import { validationResult } from 'express-validator';
import { sanitizeObjectId, sanitizeQuery } from '../utils/inputSanitizer.js';

export const getAllTeachers = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const db = getDatabase();
    const page = parseInt(req.query.page || '0');
    const limit = parseInt(req.query.limit || '20');
    const skip = page * limit;

    const teachers = await db.collection('teachers')
      .find({})
      .skip(skip)
      .limit(limit)
      .toArray();

    const total = await db.collection('teachers').countDocuments({});

    res.json({
      success: true,
      data: teachers,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    console.error('Get all teachers error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getTeacherById = async (req, res) => {
  try {
    const { id } = req.params;
    const db = getDatabase();

    // SECURITY: Sanitize user ID to prevent NoSQL injection
    let sanitizedId;
    try {
      sanitizedId = sanitizeObjectId(id);
    } catch (error) {
      return res.status(400).json({ success: false, error: 'Invalid teacher ID format' });
    }

    const teacher = await db.collection('teachers').findOne({ _id: sanitizedId });

    if (!teacher) {
      return res.status(404).json({ success: false, error: 'Teacher not found' });
    }

    res.json({ success: true, data: teacher });
  } catch (error) {
    console.error('Get teacher by ID error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const createTeacher = async (req, res) => {
  try {
    const db = getDatabase();
    const teacherData = {
      ...req.body,
      _id: new ObjectId(),
      createdExams: req.body.createdExams?.map(id => 
        typeof id === 'string' ? new ObjectId(id) : id
      ) || [],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    const result = await db.collection('teachers').insertOne(teacherData);

    res.status(201).json({
      success: true,
      data: teacherData,
      insertedId: result.insertedId.toString()
    });
  } catch (error) {
    console.error('Create teacher error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const updateTeacher = async (req, res) => {
  try {
    const { id } = req.params;
    const db = getDatabase();

    // SECURITY: Sanitize user ID to prevent NoSQL injection
    let sanitizedId;
    try {
      sanitizedId = sanitizeObjectId(id);
    } catch (error) {
      return res.status(400).json({ success: false, error: 'Invalid teacher ID format' });
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

    if (updateData.createdExams && Array.isArray(updateData.createdExams)) {
      updateData.createdExams = updateData.createdExams.map(examId => {
        try {
          return sanitizeObjectId(examId);
        } catch {
          return null;
        }
      }).filter(id => id !== null);
    }

    const result = await db.collection('teachers').updateOne(
      { _id: sanitizedId },
      { $set: updateData }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ success: false, error: 'Teacher not found' });
    }

    const updatedTeacher = await db.collection('teachers').findOne({ _id: sanitizedId });

    res.json({ success: true, data: updatedTeacher });
  } catch (error) {
    console.error('Update teacher error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const deleteTeacher = async (req, res) => {
  try {
    const { id } = req.params;
    const db = getDatabase();

    // SECURITY: Sanitize user ID to prevent NoSQL injection
    let sanitizedId;
    try {
      sanitizedId = sanitizeObjectId(id);
    } catch (error) {
      return res.status(400).json({ success: false, error: 'Invalid teacher ID format' });
    }

    const result = await db.collection('teachers').deleteOne({ _id: sanitizedId });

    if (result.deletedCount === 0) {
      return res.status(404).json({ success: false, error: 'Teacher not found' });
    }

    res.json({ success: true, message: 'Teacher deleted successfully' });
  } catch (error) {
    console.error('Delete teacher error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

