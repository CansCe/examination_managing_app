import { getDatabase } from '../config/database.js';
import { ObjectId } from 'mongodb';
import { validationResult } from 'express-validator';

// Helper function to validate ObjectId
function isValidObjectId(id) {
  try {
    return ObjectId.isValid(id) && new ObjectId(id).toString() === id;
  } catch {
    return false;
  }
}

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
      if (!isValidObjectId(req.query.teacherId)) {
        return res.status(400).json({ success: false, error: 'Invalid teacher ID' });
      }
      query.createdBy = new ObjectId(req.query.teacherId);
    }

    const exams = await db.collection('exams')
      .find(query)
      .sort({ createdAt: -1 })
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

    if (!isValidObjectId(id)) {
      return res.status(400).json({ success: false, error: 'Invalid exam ID' });
    }

    const exam = await db.collection('exams').findOne({ _id: new ObjectId(id) });

    if (!exam) {
      return res.status(404).json({ success: false, error: 'Exam not found' });
    }

    // Populate questions if exam has question IDs
    if (exam.questions && Array.isArray(exam.questions) && exam.questions.length > 0) {
      const questionIds = exam.questions.map(q => new ObjectId(q));
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
    const { questions, ...examData } = req.body;

    // Validate createdBy is a valid ObjectId
    if (examData.createdBy && !isValidObjectId(examData.createdBy)) {
      return res.status(400).json({ success: false, error: 'Invalid createdBy ID' });
    }

    // Parse examDate
    const dateValue = examData.examDate || examData.exam_date;
    const examDateObj = dateValue ? new Date(dateValue) : new Date();
    
    // Extract or set examTime
    let examTime = examData.examTime || examData.exam_time;
    if (!examTime && dateValue) {
      // If examTime not provided, extract from examDate ISO string
      let hours = '09';
      let minutes = '00';
      
      if (typeof dateValue === 'string') {
        // Try to extract time from ISO string directly to avoid timezone issues
        const timeMatch = dateValue.match(/T(\d{2}):(\d{2})/);
        if (timeMatch) {
          hours = timeMatch[1];
          minutes = timeMatch[2];
        } else {
          // Fallback to UTC hours/minutes from Date object
          hours = examDateObj.getUTCHours().toString().padStart(2, '0');
          minutes = examDateObj.getUTCMinutes().toString().padStart(2, '0');
        }
      } else {
        // If dateValue is already a Date object, use UTC methods
        hours = examDateObj.getUTCHours().toString().padStart(2, '0');
        minutes = examDateObj.getUTCMinutes().toString().padStart(2, '0');
      }
      examTime = `${hours}:${minutes}`;
    } else if (!examTime) {
      // Default to 09:00 if no time provided
      examTime = '09:00';
    }

    const examInsert = {
      title: examData.title,
      description: examData.description || '',
      subject: examData.subject,
      difficulty: examData.difficulty || 'medium',
      examDate: examDateObj,
      examTime: examTime, // Save examTime as string (HH:mm format)
      duration: examData.duration || 60,
      maxStudents: examData.maxStudents || 30,
      status: examData.status || 'scheduled',
      isDummy: examData.isDummy === true || examData.isDummy === 'true' || examData.isDummy === 1,
      createdBy: examData.createdBy ? new ObjectId(examData.createdBy) : null,
      questions: questions && Array.isArray(questions) 
        ? questions.filter(q => isValidObjectId(q)).map(q => new ObjectId(q))
        : [],
      createdAt: new Date(),
      updatedAt: new Date()
    };

    const result = await db.collection('exams').insertOne(examInsert);
    const exam = await db.collection('exams').findOne({ _id: result.insertedId });

    res.status(201).json({
      success: true,
      data: exam,
      insertedId: exam._id.toString()
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

    if (!isValidObjectId(id)) {
      return res.status(400).json({ success: false, error: 'Invalid exam ID' });
    }

    const { questions, ...updateData } = req.body;

    const examUpdate = {
      updatedAt: new Date()
    };

    if (updateData.title) examUpdate.title = updateData.title;
    if (updateData.subject) examUpdate.subject = updateData.subject;
    // Allow direct examTime update if provided separately (takes priority)
    if (updateData.examTime) {
      examUpdate.examTime = updateData.examTime;
    }
    if (updateData.examDate || updateData.exam_date) {
      const dateValue = updateData.examDate || updateData.exam_date;
      const newDate = new Date(dateValue);
      examUpdate.examDate = newDate;
      // Only extract time from examDate if examTime was not explicitly provided
      if (!updateData.examTime) {
        let hours = '09';
        let minutes = '00';
        
        if (typeof dateValue === 'string') {
          // Try to extract time from ISO string directly to avoid timezone issues
          const timeMatch = dateValue.match(/T(\d{2}):(\d{2})/);
          if (timeMatch) {
            hours = timeMatch[1];
            minutes = timeMatch[2];
          } else {
            // Fallback to UTC hours/minutes from Date object
            hours = newDate.getUTCHours().toString().padStart(2, '0');
            minutes = newDate.getUTCMinutes().toString().padStart(2, '0');
          }
        } else {
          // If dateValue is already a Date object, use UTC methods
          hours = newDate.getUTCHours().toString().padStart(2, '0');
          minutes = newDate.getUTCMinutes().toString().padStart(2, '0');
        }
        
        examUpdate.examTime = `${hours}:${minutes}`;
        console.log(`[updateExam] Updated exam time: ${examUpdate.examTime} from examDate: ${dateValue}`);
      }
    }
    if (updateData.duration) examUpdate.duration = updateData.duration;
    if (updateData.status) examUpdate.status = updateData.status;
    if (updateData.createdBy || updateData.created_by) {
      const createdBy = updateData.createdBy || updateData.created_by;
      if (!isValidObjectId(createdBy)) {
        return res.status(400).json({ success: false, error: 'Invalid createdBy ID' });
      }
      examUpdate.createdBy = new ObjectId(createdBy);
    }

    // Update questions if provided
    if (questions && Array.isArray(questions)) {
      examUpdate.questions = questions
        .filter(q => isValidObjectId(q))
        .map(q => new ObjectId(q));
    }

    const result = await db.collection('exams').updateOne(
      { _id: new ObjectId(id) },
      { $set: examUpdate }
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
    const { status, newDate } = req.body;
    const db = getDatabase();

    if (!isValidObjectId(id)) {
      return res.status(400).json({ success: false, error: 'Invalid exam ID' });
    }

    const updateData = {
      status,
      updatedAt: new Date()
    };

    // If status is delayed and newDate is provided, update both date and time
    if (status === 'delayed' && newDate) {
      const newDateTime = new Date(newDate);
      updateData.examDate = newDateTime;
      // Extract time from the ISO string to avoid timezone issues
      // The ISO string format is: "YYYY-MM-DDTHH:mm:ss.sssZ" or "YYYY-MM-DDTHH:mm:ss.sss+HH:mm"
      let hours = '09';
      let minutes = '00';
      
      if (typeof newDate === 'string') {
        // Try to extract time from ISO string directly
        const timeMatch = newDate.match(/T(\d{2}):(\d{2})/);
        if (timeMatch) {
          hours = timeMatch[1];
          minutes = timeMatch[2];
        } else {
          // Fallback to UTC hours/minutes from Date object
          hours = newDateTime.getUTCHours().toString().padStart(2, '0');
          minutes = newDateTime.getUTCMinutes().toString().padStart(2, '0');
        }
      } else {
        // If newDate is already a Date object, use UTC methods
        hours = newDateTime.getUTCHours().toString().padStart(2, '0');
        minutes = newDateTime.getUTCMinutes().toString().padStart(2, '0');
      }
      
      updateData.examTime = `${hours}:${minutes}`;
      console.log(`[updateExamStatus] Updated exam time: ${updateData.examTime} from newDate: ${newDate}`);
    }

    const result = await db.collection('exams').updateOne(
      { _id: new ObjectId(id) },
      { $set: updateData }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ success: false, error: 'Exam not found' });
    }

    const updatedExam = await db.collection('exams').findOne({ _id: new ObjectId(id) });

    res.json({ success: true, message: 'Exam status updated', data: updatedExam });
  } catch (error) {
    console.error('Update exam status error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const deleteExam = async (req, res) => {
  try {
    const { id } = req.params;
    const db = getDatabase();

    if (!isValidObjectId(id)) {
      return res.status(400).json({ success: false, error: 'Invalid exam ID' });
    }

    const examObjectId = new ObjectId(id);

    // Delete the exam
    const result = await db.collection('exams').deleteOne({ _id: examObjectId });

    if (result.deletedCount === 0) {
      return res.status(404).json({ success: false, error: 'Exam not found' });
    }

    // Clean up related data: Remove exam from student_exams collection
    const studentExamsResult = await db.collection('student_exams').deleteMany({ 
      examId: examObjectId 
    });
    console.log(`Deleted ${studentExamsResult.deletedCount} student exam assignments`);

    // Also remove exam from students' assignedExams arrays
    const studentsUpdateResult = await db.collection('students').updateMany(
      { assignedExams: examObjectId },
      { $pull: { assignedExams: examObjectId } }
    );
    console.log(`Removed exam from ${studentsUpdateResult.modifiedCount} students' assignedExams arrays`);

    res.json({ 
      success: true, 
      message: 'Exam deleted successfully',
      deletedAssignments: studentExamsResult.deletedCount,
      updatedStudents: studentsUpdateResult.modifiedCount
    });
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

    if (!isValidObjectId(teacherId)) {
      return res.status(400).json({ success: false, error: 'Invalid teacher ID' });
    }

    const exams = await db.collection('exams')
      .find({ createdBy: new ObjectId(teacherId) })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .toArray();

    const total = await db.collection('exams').countDocuments({ createdBy: new ObjectId(teacherId) });

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

    console.log(`[getStudentExams] Looking for student with ID: ${studentId}`);

    // Find student by studentId (string) or _id (ObjectId)
    let student;
    if (isValidObjectId(studentId)) {
      // Try to find by MongoDB _id first
      try {
        student = await db.collection('students').findOne({ _id: new ObjectId(studentId) });
        if (student) {
          console.log(`[getStudentExams] Found student by _id: ${student._id}`);
        }
      } catch (error) {
        console.log(`[getStudentExams] Error finding by _id: ${error.message}`);
        // Invalid ObjectId format, continue to search by studentId string
      }
    }
    
    // If not found by _id, try to find by studentId string field
    if (!student) {
      student = await db.collection('students').findOne({ 
        $or: [
          { studentId: studentId },
          { rollNumber: studentId }
        ]
      });
      if (student) {
        console.log(`[getStudentExams] Found student by studentId/rollNumber: ${student._id}`);
      }
    }

    if (!student) {
      console.log(`[getStudentExams] Student not found with ID: ${studentId}`);
      return res.status(404).json({ 
        success: false, 
        error: 'Student not found' 
      });
    }

    console.log(`[getStudentExams] Student found: _id=${student._id}, studentId=${student.studentId}, rollNumber=${student.rollNumber}`);

    // Get assigned exams from student's assignedExams array
    const assignedExamIds = student.assignedExams || [];
    console.log(`[getStudentExams] assignedExams array has ${assignedExamIds.length} exam(s):`, 
      assignedExamIds.map(id => id instanceof ObjectId ? id.toString() : String(id)));
    
    // Also check student_exams collection for additional assignments
    const studentMongoId = student._id;
    const studentExamsFromCollection = await db.collection('student_exams')
      .find({ studentId: studentMongoId })
      .toArray();
    
    console.log(`[getStudentExams] student_exams collection has ${studentExamsFromCollection.length} entry/entries`);
    
    const examIdsFromCollection = studentExamsFromCollection.map(se => se.examId);
    console.log(`[getStudentExams] Exam IDs from collection:`, 
      examIdsFromCollection.map(id => id instanceof ObjectId ? id.toString() : String(id)));
    
    // Combine both sources of exam IDs (deduplicate by converting to strings)
    const assignedIds = assignedExamIds.map(id => {
      try {
        if (id instanceof ObjectId) {
          return id.toString();
        } else if (typeof id === 'string') {
          // Validate it's a valid ObjectId string
          if (ObjectId.isValid(id)) {
            return id;
          }
          console.log(`[getStudentExams] Invalid ObjectId string in assignedExams: ${id}`);
          return null;
        }
        return null;
      } catch (e) {
        console.log(`[getStudentExams] Error converting assigned exam ID: ${id}, error: ${e.message}`);
        return null;
      }
    }).filter(id => id !== null);
    
    const collectionIds = examIdsFromCollection.map(examId => {
      try {
        if (examId instanceof ObjectId) {
          return examId.toString();
        } else if (typeof examId === 'string' && ObjectId.isValid(examId)) {
          return examId;
        }
        console.log(`[getStudentExams] Invalid examId in student_exams collection: ${examId}`);
        return null;
      } catch (e) {
        console.log(`[getStudentExams] Error converting collection exam ID: ${examId}, error: ${e.message}`);
        return null;
      }
    }).filter(id => id !== null);
    
    const uniqueIdStrings = [...new Set([...assignedIds, ...collectionIds])];
    const allExamIds = uniqueIdStrings.map(idStr => {
      try {
        return new ObjectId(idStr);
      } catch (e) {
        console.log(`[getStudentExams] Error creating ObjectId from string: ${idStr}, error: ${e.message}`);
        return null;
      }
    }).filter(id => id !== null);

    console.log(`[getStudentExams] Total unique exam IDs: ${allExamIds.length}`);
    console.log(`[getStudentExams] Exam IDs to query:`, allExamIds.map(id => id.toString()));

    if (allExamIds.length === 0) {
      console.log(`[getStudentExams] No exam IDs found, returning empty array`);
      return res.json({
        success: true,
        data: [],
        pagination: { page, limit, total: 0, pages: 0 }
      });
    }

    // Fetch all exams (no date filter - get all assigned exams)
    const exams = await db.collection('exams')
      .find({ _id: { $in: allExamIds } })
      .sort({ examDate: -1 })
      .skip(skip)
      .limit(limit)
      .toArray();

    console.log(`[getStudentExams] Found ${exams.length} exam(s) in database`);
    if (exams.length === 0 && allExamIds.length > 0) {
      console.log(`[getStudentExams] WARNING: Exam IDs exist but no exams found!`);
      console.log(`[getStudentExams] Checking if exams exist with these IDs...`);
      for (const examId of allExamIds) {
        const examExists = await db.collection('exams').findOne({ _id: examId });
        console.log(`[getStudentExams] Exam ${examId.toString()} exists: ${examExists ? 'YES' : 'NO'}`);
      }
    }

    const total = allExamIds.length;

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
    console.error('[getStudentExams] Error:', error);
    console.error('[getStudentExams] Stack:', error.stack);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const assignStudentToExam = async (req, res) => {
  try {
    const { id: examId, studentId } = req.params;
    const db = getDatabase();

    if (!isValidObjectId(examId) || !isValidObjectId(studentId)) {
      return res.status(400).json({ success: false, error: 'Invalid exam or student ID' });
    }

    // Verify exam exists
    const exam = await db.collection('exams').findOne({ _id: new ObjectId(examId) });

    if (!exam) {
      return res.status(404).json({ success: false, error: 'Exam not found' });
    }

    // Check if already assigned
    const existing = await db.collection('student_exams').findOne({
      studentId: new ObjectId(studentId),
      examId: new ObjectId(examId)
    });

    if (existing) {
      return res.json({ success: true, message: 'Student already assigned to exam' });
    }

    // Assign student to exam - update both student_exams collection AND student's assignedExams array
    await db.collection('student_exams').insertOne({
      studentId: new ObjectId(studentId),
      examId: new ObjectId(examId),
      assignedAt: new Date()
    });

    // Also update the student's assignedExams array
    await db.collection('students').updateOne(
      { _id: new ObjectId(studentId) },
      { 
        $addToSet: { assignedExams: new ObjectId(examId) },
        $set: { updatedAt: new Date() }
      }
    );

    console.log(`[assignStudentToExam] Assigned student ${studentId} to exam ${examId}`);

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

    if (!isValidObjectId(examId) || !isValidObjectId(studentId)) {
      return res.status(400).json({ success: false, error: 'Invalid exam or student ID' });
    }

    const result = await db.collection('student_exams').deleteOne({
      studentId: new ObjectId(studentId),
      examId: new ObjectId(examId)
    });

    // Also remove from student's assignedExams array
    await db.collection('students').updateOne(
      { _id: new ObjectId(studentId) },
      { 
        $pull: { assignedExams: new ObjectId(examId) },
        $set: { updatedAt: new Date() }
      }
    );

    if (result.deletedCount === 0) {
      return res.status(404).json({ success: false, error: 'Assignment not found' });
    }

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

    if (!isValidObjectId(examId)) {
      return res.status(400).json({ success: false, error: 'Invalid exam ID' });
    }

    const studentExams = await db.collection('student_exams')
      .find({ examId: new ObjectId(examId) })
      .toArray();

    const studentIds = studentExams.map(se => se.studentId);

    if (studentIds.length === 0) {
      return res.json({ success: true, data: [] });
    }

    const students = await db.collection('students')
      .find({ _id: { $in: studentIds } })
      .toArray();

    res.json({ success: true, data: students });
  } catch (error) {
    console.error('Get students assigned to exam error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

// Start exam session - record when student starts taking the exam
export const startExamSession = async (req, res) => {
  try {
    const { id: examId, studentId } = req.params;
    const db = getDatabase();

    if (!isValidObjectId(examId) || !isValidObjectId(studentId)) {
      return res.status(400).json({ success: false, error: 'Invalid exam or student ID' });
    }

    // Verify exam exists
    const exam = await db.collection('exams').findOne({ _id: new ObjectId(examId) });
    if (!exam) {
      return res.status(404).json({ success: false, error: 'Exam not found' });
    }

    // Check if student is assigned to exam
    const studentExam = await db.collection('student_exams').findOne({
      studentId: new ObjectId(studentId),
      examId: new ObjectId(examId)
    });

    if (!studentExam) {
      return res.status(404).json({ success: false, error: 'Student is not assigned to this exam' });
    }

    // Update or set startedAt timestamp
    const startedAt = new Date();
    await db.collection('student_exams').updateOne(
      {
        studentId: new ObjectId(studentId),
        examId: new ObjectId(examId)
      },
      {
        $set: { startedAt: startedAt }
      }
    );

    res.json({ 
      success: true, 
      message: 'Exam session started',
      data: { startedAt: startedAt.toISOString() }
    });
  } catch (error) {
    console.error('Start exam session error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

// Get exam status with student sessions and their timers
export const getExamStatus = async (req, res) => {
  try {
    const { id: examId } = req.params;
    const db = getDatabase();

    if (!isValidObjectId(examId)) {
      return res.status(400).json({ success: false, error: 'Invalid exam ID' });
    }

    // Get exam details
    const exam = await db.collection('exams').findOne({ _id: new ObjectId(examId) });
    if (!exam) {
      return res.status(404).json({ success: false, error: 'Exam not found' });
    }

    // Calculate exam state
    const now = new Date();
    let examState = 'scheduled'; // scheduled, in_progress, finished
    
    // Parse exam time
    const examDate = new Date(exam.examDate);
    let examStartTime = examDate;
    
    if (exam.examTime && typeof exam.examTime === 'string' && exam.examTime.includes(':')) {
      const [hours, minutes] = exam.examTime.split(':').map(Number);
      examStartTime = new Date(examDate);
      examStartTime.setHours(hours, minutes, 0, 0);
    }
    
    const examEndTime = new Date(examStartTime.getTime() + (exam.duration * 60 * 1000));
    
    if (now < examStartTime) {
      examState = 'scheduled';
    } else if (now >= examStartTime && now < examEndTime) {
      examState = 'in_progress';
    } else {
      examState = 'finished';
    }

    // Get all student sessions for this exam
    const studentExams = await db.collection('student_exams')
      .find({ examId: new ObjectId(examId) })
      .toArray();

    const studentIds = studentExams.map(se => se.studentId);
    const students = studentIds.length > 0
      ? await db.collection('students')
          .find({ _id: { $in: studentIds } })
          .toArray()
      : [];

    // Create a map of studentId to student data
    const studentMap = {};
    students.forEach(student => {
      studentMap[student._id.toString()] = student;
    });

    // Get all exam results for this exam to check completion status
    const examResults = await db.collection('exam_results')
      .find({ examId: new ObjectId(examId) })
      .toArray();
    
    // Create a map of studentId to exam result
    const resultMap = {};
    examResults.forEach(result => {
      resultMap[result.studentId.toString()] = result;
    });

    // Calculate student sessions with timers
    const studentSessions = studentExams.map(se => {
      const student = studentMap[se.studentId.toString()];
      const examResult = resultMap[se.studentId.toString()];
      let sessionStatus = 'not_started';
      let remainingTime = null;
      let startedAt = se.startedAt ? new Date(se.startedAt) : null;
      let score = null;
      let percentageScore = null;

      // Check if student has completed the exam (has a result)
      if (examResult) {
        sessionStatus = 'completed';
        score = examResult.earnedPoints || 0;
        percentageScore = examResult.percentageScore || 0;
      } else if (startedAt) {
        sessionStatus = 'in_progress';
        // Calculate remaining time: ExamDuration - (CurrentTime - StartTime)
        const elapsed = now.getTime() - startedAt.getTime();
        const totalDuration = exam.duration * 60 * 1000; // Convert minutes to milliseconds
        const remaining = totalDuration - elapsed;
        
        if (remaining <= 0) {
          sessionStatus = 'time_up';
          remainingTime = 0;
        } else {
          remainingTime = Math.floor(remaining / 1000); // Convert to seconds
        }
      } else if (examState === 'in_progress') {
        sessionStatus = 'not_started';
      } else if (examState === 'finished') {
        sessionStatus = 'finished';
      }

      return {
        studentId: se.studentId.toString(),
        studentName: student ? (student.name || student.studentId || 'Unknown') : 'Unknown',
        studentRollNumber: student ? (student.rollNumber || student.studentId || '') : '',
        sessionStatus: sessionStatus,
        startedAt: startedAt ? startedAt.toISOString() : null,
        remainingTime: remainingTime, // in seconds
        assignedAt: se.assignedAt ? new Date(se.assignedAt).toISOString() : null,
        score: score, // Exam score if completed
        percentageScore: percentageScore, // Percentage score if completed
        completedAt: examResult ? examResult.submittedAt : null
      };
    });

    res.json({
      success: true,
      data: {
        examId: exam._id.toString(),
        examTitle: exam.title,
        examState: examState,
        examStartTime: examStartTime.toISOString(),
        examEndTime: examEndTime.toISOString(),
        examDuration: exam.duration, // in minutes
        currentTime: now.toISOString(),
        studentSessions: studentSessions
      }
    });
  } catch (error) {
    console.error('Get exam status error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};
