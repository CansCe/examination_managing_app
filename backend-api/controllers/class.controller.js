import { getDatabase } from '../config/database.js';
import { ObjectId } from 'mongodb';
import { validationResult } from 'express-validator';
import { sanitizeObjectId, sanitizeQuery } from '../utils/inputSanitizer.js';

// Get all classes
export const getAllClasses = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const db = getDatabase();
    const page = parseInt(req.query.page || '0');
    const limit = parseInt(req.query.limit || '100');
    const skip = page * limit;

    // Optional filters
    const teacherId = req.query.teacherId;
    const subject = req.query.subject;

    const query = {};
    if (teacherId) {
      try {
        query.teacher = sanitizeObjectId(teacherId);
      } catch (error) {
        return res.status(400).json({ success: false, error: 'Invalid teacher ID format' });
      }
    }
    if (subject) {
      query.subject = subject;
    }

    const classes = await db.collection('classes')
      .find(query)
      .skip(skip)
      .limit(limit)
      .toArray();

    const total = await db.collection('classes').countDocuments(query);

    res.json({
      success: true,
      data: classes,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    console.error('Get all classes error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

// Get class by ID
export const getClassById = async (req, res) => {
  try {
    const { id } = req.params;
    const db = getDatabase();

    // SECURITY: Sanitize class ID to prevent NoSQL injection
    let sanitizedId;
    try {
      sanitizedId = sanitizeObjectId(id);
    } catch (error) {
      return res.status(400).json({ success: false, error: 'Invalid class ID format' });
    }

    const classData = await db.collection('classes').findOne({ _id: sanitizedId });

    if (!classData) {
      return res.status(404).json({ success: false, error: 'Class not found' });
    }

    res.json({ success: true, data: classData });
  } catch (error) {
    console.error('Get class by ID error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

// Get class by class name
export const getClassByName = async (req, res) => {
  try {
    const { className } = req.params;
    const db = getDatabase();

    const classData = await db.collection('classes').findOne({ className: className });

    if (!classData) {
      return res.status(404).json({ success: false, error: 'Class not found' });
    }

    res.json({ success: true, data: classData });
  } catch (error) {
    console.error('Get class by name error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

// Get students in a class
export const getClassStudents = async (req, res) => {
  try {
    const { id } = req.params;
    const db = getDatabase();

    // SECURITY: Sanitize class ID
    let sanitizedId;
    try {
      sanitizedId = sanitizeObjectId(id);
    } catch (error) {
      return res.status(400).json({ success: false, error: 'Invalid class ID format' });
    }

    const classData = await db.collection('classes').findOne({ _id: sanitizedId });

    if (!classData) {
      return res.status(404).json({ success: false, error: 'Class not found' });
    }

    const studentList = classData.studentList || [];
    const page = parseInt(req.query.page || '0');
    const limit = parseInt(req.query.limit || '100');
    const skip = page * limit;

    // Fetch student details
    const studentIds = studentList.map(id => 
      typeof id === 'string' ? sanitizeObjectId(id) : id
    ).filter(id => id !== null);

    const students = await db.collection('students')
      .find({ _id: { $in: studentIds } })
      .skip(skip)
      .limit(limit)
      .toArray();

    res.json({
      success: true,
      data: students,
      pagination: {
        page,
        limit,
        total: studentList.length,
        pages: Math.ceil(studentList.length / limit)
      }
    });
  } catch (error) {
    console.error('Get class students error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

// Create a new class
export const createClass = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const db = getDatabase();
    
    const classData = {
      ...req.body,
      _id: new ObjectId(),
      className: req.body.className || req.body.name,
      numStudent: req.body.studentList?.length || 0,
      studentList: (req.body.studentList || []).map(id => 
        typeof id === 'string' ? new ObjectId(id) : id
      ),
      teacher: req.body.teacher ? (
        typeof req.body.teacher === 'string' ? new ObjectId(req.body.teacher) : req.body.teacher
      ) : null,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    const result = await db.collection('classes').insertOne(classData);

    res.status(201).json({
      success: true,
      data: classData,
      insertedId: result.insertedId.toString()
    });
  } catch (error) {
    console.error('Create class error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

// Update class
export const updateClass = async (req, res) => {
  try {
    const { id } = req.params;
    const db = getDatabase();

    // SECURITY: Sanitize class ID
    let sanitizedId;
    try {
      sanitizedId = sanitizeObjectId(id);
    } catch (error) {
      return res.status(400).json({ success: false, error: 'Invalid class ID format' });
    }

    // SECURITY: Sanitize update data
    const sanitizedBody = sanitizeQuery(req.body);
    const updateData = {
      ...sanitizedBody,
      updatedAt: new Date().toISOString()
    };

    // Remove MongoDB operators
    delete updateData._id;
    delete updateData.$set;
    delete updateData.$unset;
    delete updateData.$inc;
    delete updateData.$push;
    delete updateData.$pull;

    // Handle studentList update
    if (updateData.studentList && Array.isArray(updateData.studentList)) {
      updateData.studentList = updateData.studentList.map(id => {
        try {
          return typeof id === 'string' ? sanitizeObjectId(id) : id;
        } catch {
          return null;
        }
      }).filter(id => id !== null);
      updateData.numStudent = updateData.studentList.length;
    }

    // Handle teacher update
    if (updateData.teacher) {
      try {
        updateData.teacher = typeof updateData.teacher === 'string' 
          ? sanitizeObjectId(updateData.teacher) 
          : updateData.teacher;
      } catch {
        return res.status(400).json({ success: false, error: 'Invalid teacher ID format' });
      }
    }

    const result = await db.collection('classes').updateOne(
      { _id: sanitizedId },
      { $set: updateData }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ success: false, error: 'Class not found' });
    }

    const updatedClass = await db.collection('classes').findOne({ _id: sanitizedId });

    res.json({ success: true, data: updatedClass });
  } catch (error) {
    console.error('Update class error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

// Delete class
export const deleteClass = async (req, res) => {
  try {
    const { id } = req.params;
    const db = getDatabase();

    // SECURITY: Sanitize class ID
    let sanitizedId;
    try {
      sanitizedId = sanitizeObjectId(id);
    } catch (error) {
      return res.status(400).json({ success: false, error: 'Invalid class ID format' });
    }

    const result = await db.collection('classes').deleteOne({ _id: sanitizedId });

    if (result.deletedCount === 0) {
      return res.status(404).json({ success: false, error: 'Class not found' });
    }

    res.json({ success: true, message: 'Class deleted successfully' });
  } catch (error) {
    console.error('Delete class error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

// Add student to class
export const addStudentToClass = async (req, res) => {
  try {
    const { id } = req.params;
    const { studentId } = req.body;
    const db = getDatabase();

    // SECURITY: Sanitize IDs
    let sanitizedClassId, sanitizedStudentId;
    try {
      sanitizedClassId = sanitizeObjectId(id);
      sanitizedStudentId = sanitizeObjectId(studentId);
    } catch (error) {
      return res.status(400).json({ success: false, error: 'Invalid ID format' });
    }

    const classData = await db.collection('classes').findOne({ _id: sanitizedClassId });
    if (!classData) {
      return res.status(404).json({ success: false, error: 'Class not found' });
    }

    const studentList = classData.studentList || [];
    if (studentList.some(id => id.toString() === sanitizedStudentId.toString())) {
      return res.status(400).json({ success: false, error: 'Student already in class' });
    }

    studentList.push(sanitizedStudentId);

    const result = await db.collection('classes').updateOne(
      { _id: sanitizedClassId },
      { 
        $set: { 
          studentList: studentList,
          numStudent: studentList.length,
          updatedAt: new Date().toISOString()
        }
      }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ success: false, error: 'Class not found' });
    }

    const updatedClass = await db.collection('classes').findOne({ _id: sanitizedClassId });

    res.json({ success: true, data: updatedClass });
  } catch (error) {
    console.error('Add student to class error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

// Remove student from class
export const removeStudentFromClass = async (req, res) => {
  try {
    const { id, studentId } = req.params;
    const db = getDatabase();

    // SECURITY: Sanitize IDs
    let sanitizedClassId, sanitizedStudentId;
    try {
      sanitizedClassId = sanitizeObjectId(id);
      sanitizedStudentId = sanitizeObjectId(studentId);
    } catch (error) {
      return res.status(400).json({ success: false, error: 'Invalid ID format' });
    }

    const classData = await db.collection('classes').findOne({ _id: sanitizedClassId });
    if (!classData) {
      return res.status(404).json({ success: false, error: 'Class not found' });
    }

    const studentList = (classData.studentList || []).filter(
      id => id.toString() !== sanitizedStudentId.toString()
    );

    const result = await db.collection('classes').updateOne(
      { _id: sanitizedClassId },
      { 
        $set: { 
          studentList: studentList,
          numStudent: studentList.length,
          updatedAt: new Date().toISOString()
        }
      }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ success: false, error: 'Class not found' });
    }

    const updatedClass = await db.collection('classes').findOne({ _id: sanitizedClassId });

    res.json({ success: true, data: updatedClass });
  } catch (error) {
    console.error('Remove student from class error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

