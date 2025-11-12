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

    // Get client IP address for session tracking
    const clientIp = req.ip || req.connection.remoteAddress || 'unknown';
    const userAgent = req.get('user-agent') || 'unknown';

    // Try to find student first
    let student = await db.collection('students').findOne({
      $or: [
        { username: sanitizedUsername },
        { studentId: sanitizedUsername }
      ],
      password: sanitizedPassword
    });

    if (student) {
      const userId = student._id.toString();
      const role = 'student';

      // Check for existing active session
      const existingSession = await db.collection('sessions').findOne({
        userId: userId,
        role: role,
        isActive: true
      });

      if (existingSession) {
        // User is already logged in from another device
        return res.status(403).json({
          success: false,
          error: 'User is already logged in on another device. Please logout from the other device first.'
        });
      }

      // Create new session
      const sessionId = new ObjectId();
      await db.collection('sessions').insertOne({
        _id: sessionId,
        userId: userId,
        role: role,
        clientIp: clientIp,
        userAgent: userAgent,
        isActive: true,
        createdAt: new Date(),
        lastActivity: new Date()
      });

      return res.json({
        success: true,
        user: {
          id: userId,
          username: student.username || student.studentId || student.email,
          role: role,
          fullName: student.fullName || `${student.firstName || ''} ${student.lastName || ''}`.trim(),
          sessionId: sessionId.toString()
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
      const userId = teacher._id.toString();
      const role = 'teacher';

      // Check for existing active session
      const existingSession = await db.collection('sessions').findOne({
        userId: userId,
        role: role,
        isActive: true
      });

      if (existingSession) {
        // User is already logged in from another device
        return res.status(403).json({
          success: false,
          error: 'User is already logged in on another device. Please logout from the other device first.'
        });
      }

      // Create new session
      const sessionId = new ObjectId();
      await db.collection('sessions').insertOne({
        _id: sessionId,
        userId: userId,
        role: role,
        clientIp: clientIp,
        userAgent: userAgent,
        isActive: true,
        createdAt: new Date(),
        lastActivity: new Date()
      });

      return res.json({
        success: true,
        user: {
          id: userId,
          username: teacher.username || teacher.email,
          role: role,
          fullName: teacher.fullName || `${teacher.firstName || ''} ${teacher.lastName || ''}`.trim(),
          sessionId: sessionId.toString()
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
      const userId = admin._id.toString();
      const role = 'admin';

      // Check for existing active session
      const existingSession = await db.collection('sessions').findOne({
        userId: userId,
        role: role,
        isActive: true
      });

      if (existingSession) {
        // User is already logged in from another device
        return res.status(403).json({
          success: false,
          error: 'User is already logged in on another device. Please logout from the other device first.'
        });
      }

      // Create new session
      const sessionId = new ObjectId();
      await db.collection('sessions').insertOne({
        _id: sessionId,
        userId: userId,
        role: role,
        clientIp: clientIp,
        userAgent: userAgent,
        isActive: true,
        createdAt: new Date(),
        lastActivity: new Date()
      });

      return res.json({
        success: true,
        user: {
          id: userId,
          username: admin.username || admin.email,
          role: role,
          fullName: admin.fullName || `${admin.firstName || ''} ${admin.lastName || ''}`.trim(),
          sessionId: sessionId.toString()
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

export const logout = async (req, res) => {
  try {
    const { sessionId } = req.body;
    const db = getDatabase();

    if (!sessionId) {
      return res.status(400).json({
        success: false,
        error: 'Session ID is required'
      });
    }

    // SECURITY: Sanitize session ID
    let sanitizedSessionId;
    try {
      sanitizedSessionId = sanitizeObjectId(sessionId);
    } catch (error) {
      return res.status(400).json({
        success: false,
        error: 'Invalid session ID format'
      });
    }

    // Deactivate session
    await db.collection('sessions').updateOne(
      { _id: sanitizedSessionId },
      { $set: { isActive: false, loggedOutAt: new Date() } }
    );

    return res.json({
      success: true,
      message: 'Logged out successfully'
    });
  } catch (error) {
    console.error('Logout error:', error);
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
