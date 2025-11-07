import { getDatabase } from '../config/database.js';
import { ObjectId } from 'mongodb';
import { validationResult } from 'express-validator';

export const login = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { username, password } = req.body;
    const db = getDatabase();

    // Try to find student first
    let student = await db.collection('students').findOne({
      $or: [
        { username: username },
        { studentId: username }
      ],
      password: password
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
        { username: username },
        { email: username }
      ],
      password: password
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
        { username: username },
        { email: username }
      ],
      password: password,
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

    let user;
    let role;

    // Try to find in students collection first
    try {
      user = await db.collection('students').findOne({ _id: new ObjectId(userId) });
      if (user) {
        role = 'student';
      }
    } catch (error) {
      // Invalid ObjectId, continue to next collection
    }

    // If not found, try teachers collection
    if (!user) {
      try {
        user = await db.collection('teachers').findOne({ _id: new ObjectId(userId) });
        if (user) {
          role = 'teacher';
        }
      } catch (error) {
        // Invalid ObjectId, continue to next collection
      }
    }

    // If not found, try users collection (for admins)
    if (!user) {
      try {
        user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
        if (user) {
          role = user.role || 'admin';
        }
      } catch (error) {
        // Invalid ObjectId
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

    let user;
    let collection;

    // Try to find user in students collection first
    try {
      user = await db.collection('students').findOne({
        _id: new ObjectId(userId),
        password: currentPassword
      });
      if (user) {
        collection = 'students';
      }
    } catch (error) {
      // Invalid ObjectId, continue to next collection
    }

    // If not found, try teachers collection
    if (!user) {
      try {
        user = await db.collection('teachers').findOne({
          _id: new ObjectId(userId),
          password: currentPassword
        });
        if (user) {
          collection = 'teachers';
        }
      } catch (error) {
        // Invalid ObjectId, continue to next collection
      }
    }

    // If not found, try users collection (for admins)
    if (!user) {
      try {
        user = await db.collection('users').findOne({
          _id: new ObjectId(userId),
          password: currentPassword
        });
        if (user) {
          collection = 'users';
        }
      } catch (error) {
        // Invalid ObjectId
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
      { _id: new ObjectId(userId) },
      { $set: { password: newPassword } }
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
