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
    let user = await db.collection('students').findOne({
      $or: [
        { username: username },
        { studentId: username }
      ],
      password: password
    });

    // If not found, try teacher
    if (!user) {
      user = await db.collection('teachers').findOne({
        $or: [
          { username: username },
          { email: username }
        ],
        password: password
      });
    }

    // If not found, try admin
    if (!user) {
      user = await db.collection('users').findOne({
        $or: [
          { username: username },
          { email: username }
        ],
        password: password,
        role: 'admin'
      });
    }

    if (!user) {
      return res.status(401).json({
        success: false,
        error: 'Invalid username or password'
      });
    }

    // Determine role
    let role = 'student';
    if (user.role === 'admin') {
      role = 'admin';
    } else if (user.department) {
      role = 'teacher';
    }

    // Return user data (without password)
    const { password: _, ...userData } = user;
    
    res.json({
      success: true,
      user: {
        id: user._id.toString(),
        username: user.username || user.studentId || user.email,
        role: role,
        fullName: user.fullName || `${user.firstName || ''} ${user.lastName || ''}`.trim()
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error during login'
    });
  }
};

export const getCurrentUser = async (req, res) => {
  try {
    const { userId } = req.params;
    const db = getDatabase();

    // Try to find in students collection
    let user = await db.collection('students').findOne({ _id: new ObjectId(userId) });

    // Try teachers collection
    if (!user) {
      user = await db.collection('teachers').findOne({ _id: new ObjectId(userId) });
    }

    // Try users collection (admins)
    if (!user) {
      user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
    }

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    // Determine role
    let role = 'student';
    if (user.role === 'admin') {
      role = 'admin';
    } else if (user.department) {
      role = 'teacher';
    }

    const { password: _, ...userData } = user;

    res.json({
      success: true,
      user: {
        id: user._id.toString(),
        username: user.username || user.studentId || user.email,
        role: role,
        fullName: user.fullName || `${user.firstName || ''} ${user.lastName || ''}`.trim(),
        ...userData
      }
    });
  } catch (error) {
    console.error('Get current user error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error'
    });
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

    // Try to find user in students collection
    let user = await db.collection('students').findOne({ 
      _id: new ObjectId(userId),
      password: currentPassword 
    });

    // Try teachers collection
    if (!user) {
      user = await db.collection('teachers').findOne({ 
        _id: new ObjectId(userId),
        password: currentPassword 
      });
    }

    // Try users collection
    if (!user) {
      user = await db.collection('users').findOne({ 
        _id: new ObjectId(userId),
        password: currentPassword 
      });
    }

    if (!user) {
      return res.status(401).json({
        success: false,
        error: 'Invalid current password'
      });
    }

    // Update password
    const collection = user.role === 'admin' 
      ? 'users' 
      : user.department 
        ? 'teachers' 
        : 'students';

    await db.collection(collection).updateOne(
      { _id: new ObjectId(userId) },
      { $set: { password: newPassword, updatedAt: new Date().toISOString() } }
    );

    res.json({
      success: true,
      message: 'Password changed successfully'
    });
  } catch (error) {
    console.error('Change password error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error'
    });
  }
};

