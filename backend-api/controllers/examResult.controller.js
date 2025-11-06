import { getDatabase } from '../config/database.js';
import { ObjectId } from 'mongodb';
import { validationResult } from 'express-validator';

export const submitExamAnswers = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { examId, studentId, answers, questions, isTimeUp = false } = req.body;
    const db = getDatabase();

    // Auto-grade the exam
    let totalQuestions = questions.length;
    let correctAnswers = 0;
    let totalPoints = 0;
    let earnedPoints = 0;
    const questionResults = {};

    questions.forEach((question, index) => {
      const studentAnswer = answers[index];
      totalPoints += question.points || 1;

      const isCorrect = studentAnswer && studentAnswer === question.correctAnswer;
      if (isCorrect) {
        correctAnswers++;
        earnedPoints += question.points || 1;
      }

      questionResults[index] = isCorrect;
    });

    const percentageScore = totalQuestions > 0 
      ? (correctAnswers / totalQuestions) * 100 
      : 0;

    // Create exam result document
    const examResult = {
      _id: new ObjectId(),
      examId: new ObjectId(examId),
      studentId: new ObjectId(studentId),
      answers: answers,
      submittedAt: new Date().toISOString(),
      isTimeUp: isTimeUp,
      createdAt: new Date().toISOString(),
      status: 'graded',
      totalQuestions: totalQuestions,
      correctAnswers: correctAnswers,
      earnedPoints: earnedPoints,
      totalPoints: totalPoints,
      percentageScore: percentageScore,
      gradedAt: new Date().toISOString(),
      questionResults: questionResults
    };

    await db.collection('exam_results').insertOne(examResult);

    res.status(201).json({
      success: true,
      data: {
        totalQuestions,
        correctAnswers,
        earnedPoints,
        totalPoints,
        percentageScore: Math.round(percentageScore * 100) / 100
      }
    });
  } catch (error) {
    console.error('Submit exam answers error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getExamResult = async (req, res) => {
  try {
    const { examId, studentId } = req.params;
    const db = getDatabase();

    const result = await db.collection('exam_results').findOne({
      examId: new ObjectId(examId),
      studentId: new ObjectId(studentId)
    });

    if (!result) {
      return res.status(404).json({ success: false, error: 'Exam result not found' });
    }

    res.json({ success: true, data: result });
  } catch (error) {
    console.error('Get exam result error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getStudentResults = async (req, res) => {
  try {
    const { studentId } = req.params;
    const db = getDatabase();

    const results = await db.collection('exam_results')
      .find({ studentId: new ObjectId(studentId) })
      .toArray();

    res.json({ success: true, data: results });
  } catch (error) {
    console.error('Get student results error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

export const getExamResults = async (req, res) => {
  try {
    const { examId } = req.params;
    const db = getDatabase();

    const results = await db.collection('exam_results')
      .find({ examId: new ObjectId(examId) })
      .toArray();

    res.json({ success: true, data: results });
  } catch (error) {
    console.error('Get exam results error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
};

