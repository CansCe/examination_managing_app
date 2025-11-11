import { getDatabase } from '../config/database.js';
import { ObjectId } from 'mongodb';
import { validationResult } from 'express-validator';
import { sanitizeObjectId, sanitizeQuery } from '../utils/inputSanitizer.js';

export const getAllQuestions = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const db = getDatabase();
    const page = parseInt(req.query.page || '0');
    const limit = parseInt(req.query.limit || '20');
    const skip = page * limit;

    const questions = await db.collection('questions')
      .find({})
      .skip(skip)
      .limit(limit)
      .toArray();

    const total = await db.collection('questions').countDocuments({});

    res.json({
      success: true,
      data: questions,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    console.error('Get all questions error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getQuestionsByIds = async (req, res) => {
  try {
    const idsParam = req.query.ids;
    if (!idsParam) {
      return res.status(400).json({ success: false, error: 'ids parameter is required' });
    }

    const ids = idsParam.split(',').map(id => {
      try {
        return new ObjectId(id.trim());
      } catch {
        return null;
      }
    }).filter(id => id !== null);

    if (ids.length === 0) {
      return res.status(400).json({ success: false, error: 'No valid IDs provided' });
    }

    const db = getDatabase();
    const questions = await db.collection('questions')
      .find({ _id: { $in: ids } })
      .toArray();

    res.json({ success: true, data: questions });
  } catch (error) {
    console.error('Get questions by IDs error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getQuestionById = async (req, res) => {
  try {
    const { id } = req.params;
    const db = getDatabase();

    // SECURITY: Sanitize user ID to prevent NoSQL injection
    let sanitizedId;
    try {
      sanitizedId = sanitizeObjectId(id);
    } catch (error) {
      return res.status(400).json({ success: false, error: 'Invalid question ID format' });
    }

    const question = await db.collection('questions').findOne({ _id: sanitizedId });

    if (!question) {
      return res.status(404).json({ success: false, error: 'Question not found' });
    }

    res.json({ success: true, data: question });
  } catch (error) {
    console.error('Get question by ID error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const createQuestion = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const db = getDatabase();
    const questionData = {
      ...req.body,
      _id: new ObjectId(),
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    const result = await db.collection('questions').insertOne(questionData);

    res.status(201).json({
      success: true,
      data: questionData,
      insertedId: result.insertedId.toString()
    });
  } catch (error) {
    console.error('Create question error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const updateQuestion = async (req, res) => {
  try {
    const { id } = req.params;
    const db = getDatabase();

    // SECURITY: Sanitize user ID to prevent NoSQL injection
    let sanitizedId;
    try {
      sanitizedId = sanitizeObjectId(id);
    } catch (error) {
      return res.status(400).json({ success: false, error: 'Invalid question ID format' });
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

    const result = await db.collection('questions').updateOne(
      { _id: sanitizedId },
      { $set: updateData }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ success: false, error: 'Question not found' });
    }

    const updatedQuestion = await db.collection('questions').findOne({ _id: sanitizedId });

    res.json({ success: true, data: updatedQuestion });
  } catch (error) {
    console.error('Update question error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const deleteQuestion = async (req, res) => {
  try {
    const { id } = req.params;
    const db = getDatabase();

    // SECURITY: Sanitize user ID to prevent NoSQL injection
    let sanitizedId;
    try {
      sanitizedId = sanitizeObjectId(id);
    } catch (error) {
      return res.status(400).json({ success: false, error: 'Invalid question ID format' });
    }

    const result = await db.collection('questions').deleteOne({ _id: sanitizedId });

    if (result.deletedCount === 0) {
      return res.status(404).json({ success: false, error: 'Question not found' });
    }

    res.json({ success: true, message: 'Question deleted successfully' });
  } catch (error) {
    console.error('Delete question error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

