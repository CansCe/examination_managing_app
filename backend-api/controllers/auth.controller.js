import { getDatabase } from '../config/database.js';
import { ObjectId } from 'mongodb';
import { validationResult } from 'express-validator';
import { sanitizeUsername, sanitizePassword, sanitizeObjectId } from '../utils/inputSanitizer.js';

export const login = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { username, password } = req.body;
    const db = getDatabase();

    // SECURITY: Sanitize user inputs to prevent NoSQL injection
    const sanitizedUsername = sanitizeUsername(username);
    const sanitizedPassword = sanitizePassword(password);

    // Try to find student first
    let student = await db.collection('students').findOne({
      $or: [
        { username: sanitizedUsername },
        { studentId: sanitizedUsername }
      ],
      password: sanitizedPassword
    });

    if (student) {
      return res.json({
        success: true,
        user: {
          id: student._id.toString(),
          username: student.username || student.studentId || student.email,
          role: 'student',
          fullName: student.fullName || `${student.firstName || ''} ${student.lastName || ''}`.trim()
        }
      });
    }

    // Try teacher
    let teacher = await db.collection('teachers').findOne({
      $or: [
        { username: sanitizedUsername },
        { email: sanitizedUsername }
      ],
      password: sanitizedPassword
    });

    if (teacher) {
      return res.json({
        success: true,
        user: {
          id: teacher._id.toString(),
          username: teacher.username || teacher.email,
          role: 'teacher',
          fullName: teacher.fullName || `${teacher.firstName || ''} ${teacher.lastName || ''}`.trim()
        }
      });
    }

    // Try admin (in users collection)
    let admin = await db.collection('users').findOne({
      $or: [
        { username: sanitizedUsername },
        { email: sanitizedUsername }
      ],
      password: sanitizedPassword,
      role: 'admin'
    });

    if (admin) {
      return res.json({
        success: true,
        user: {
          id: admin._id.toString(),
          username: admin.username || admin.email,
          role: 'admin',
          fullName: admin.fullName || `${admin.firstName || ''} ${admin.lastName || ''}`.trim()
        }
      });
    }

    return res.status(401).json({
      success: false,
      error: 'Invalid username or password'
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getCurrentUser = async (req, res) => {
  try {
    const { userId } = req.params;
    const db = getDatabase();

    // SECURITY: Sanitize user ID to prevent NoSQL injection
    let sanitizedUserId;
    try {
      sanitizedUserId = sanitizeObjectId(userId);
    } catch (error) {
      return res.status(400).json({
        success: false,
        error: 'Invalid user ID format'
      });
    }

    let user;
    let role;

    // Try to find in students collection first
    user = await db.collection('students').findOne({ _id: sanitizedUserId });
    if (user) {
      role = 'student';
    }

    // If not found, try teachers collection
    if (!user) {
      user = await db.collection('teachers').findOne({ _id: sanitizedUserId });
      if (user) {
        role = 'teacher';
      }
    }

    // If not found, try users collection (for admins)
    if (!user) {
      user = await db.collection('users').findOne({ _id: sanitizedUserId });
      if (user) {
        role = user.role || 'admin';
      }
    }

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    const { password: _, ...userData } = user;

    return res.json({
      success: true,
      user: {
        id: user._id.toString(),
        username: user.username || user.studentId || user.email,
        role: role,
        fullName: user.fullName || `${user.firstName || ''} ${user.lastName || ''}`.trim()
      }
    });
  } catch (error) {
    console.error('Get current user error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const changePassword = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { userId, currentPassword, newPassword } = req.body;
    const db = getDatabase();

    // SECURITY: Sanitize all inputs to prevent NoSQL injection
    let sanitizedUserId;
    try {
      sanitizedUserId = sanitizeObjectId(userId);
    } catch (error) {
      return res.status(400).json({
        success: false,
        error: 'Invalid user ID format'
      });
    }
    
    const sanitizedCurrentPassword = sanitizePassword(currentPassword);
    const sanitizedNewPassword = sanitizePassword(newPassword);

    let user;
    let collection;

    // Try to find user in students collection first
    user = await db.collection('students').findOne({
      _id: sanitizedUserId,
      password: sanitizedCurrentPassword
    });
    if (user) {
      collection = 'students';
    }

    // If not found, try teachers collection
    if (!user) {
      user = await db.collection('teachers').findOne({
        _id: sanitizedUserId,
        password: sanitizedCurrentPassword
      });
      if (user) {
        collection = 'teachers';
      }
    }

    // If not found, try users collection (for admins)
    if (!user) {
      user = await db.collection('users').findOne({
        _id: sanitizedUserId,
        password: sanitizedCurrentPassword
      });
      if (user) {
        collection = 'users';
      }
    }

    if (!user) {
      return res.status(401).json({
        success: false,
        error: 'Invalid user ID or current password'
      });
    }

    // Update password
    await db.collection(collection).updateOne(
      { _id: sanitizedUserId },
      { $set: { password: sanitizedNewPassword } }
    );

    return res.json({
      success: true,
      message: 'Password changed successfully'
    });
  } catch (error) {
    console.error('Change password error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};
