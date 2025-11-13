import 'package:flutter/material.dart';
import '../models/index.dart';
import '../services/atlas_service.dart';
import '../services/api_service.dart';
import 'dart:async';

class ExaminationPage extends StatefulWidget {
  final Exam exam;
  final List<Question> questions;
  final String? studentId; // Student ID for submitting answers

  const ExaminationPage({
    super.key,
    required this.exam,
    required this.questions,
    this.studentId,
  });

  @override
  State<ExaminationPage> createState() => _ExaminationPageState();
}

class _ExaminationPageState extends State<ExaminationPage> {
  int _currentQuestionIndex = 0;
  final Map<int, String> _answers = {};
  Timer? _timer; // Nullable for dummy exams
  late Duration _remainingTime;
  bool _isExamSubmitted = false;
  bool _isSubmitting = false;
  bool _isTimeUp = false;
  DateTime? _examStartDateTime; // Exam scheduled start time
  DateTime? _examEndDateTime; // Exam scheduled end time
  DateTime? _sessionStartTime; // When student actually started the exam
  bool _sessionStarted = false;
  
  @override
  void initState() {
    super.initState();
    
    // All exams (dummy and normal) use the same algorithm
    // Calculate start time and end time for all exams
    _calculateExamTimes();
    
    // Record exam session start time if student is taking the exam
    if (widget.studentId != null) {
      _startExamSession();
    }
    
    // Check if exam has already ended - if so, auto-submit immediately
    // Otherwise, start the timer for real-time monitoring
    if (_examEndDateTime != null) {
      final now = DateTime.now();
      // Auto-submit when: currentTime >= (startTime + examDuration)
      // This is equivalent to: currentTime >= endTime
      if (now.isAfter(_examEndDateTime!) || now.isAtSameMomentAs(_examEndDateTime!)) {
        // Exam has already ended - submit immediately
        Future.microtask(() {
          if (mounted && !_isExamSubmitted) {
            _submitExam(isTimeUp: true);
          }
        });
      } else {
        // Exam is still in progress - start timer for real-time monitoring
        _startTimer();
      }
    }
  }

  /// Start exam session - record when student starts taking the exam
  Future<void> _startExamSession() async {
    if (widget.studentId == null || _sessionStarted) return;
    
    try {
      final api = ApiService();
      final examId = widget.exam.id.toHexString();
      _sessionStartTime = await api.startExamSession(examId, widget.studentId!);
      api.close();
      
      if (mounted) {
        setState(() {
          _sessionStarted = true;
        });
        // Recalculate remaining time based on session start
        _updateRemainingTime();
      }
    } catch (e) {
      // If API call fails, use current time as fallback
      _sessionStartTime = DateTime.now();
      if (mounted) {
        setState(() {
          _sessionStarted = true;
        });
        _updateRemainingTime();
      }
    }
  }

  void _calculateExamTimes() {
    // All exams (dummy and normal) use the same calculation
    // Calculate actual exam start and end times
    // End time = Start time + Exam duration (in 24-hour format)
    try {
      // Get exam date (ensure it's a valid DateTime)
      final examDate = widget.exam.examDate;
      
      // Parse examTime (format: HH:mm in 24-hour format)
      final examTimeStr = widget.exam.examTime;
      if (examTimeStr.isEmpty || !examTimeStr.contains(':')) {
        // Invalid examTime format - use default
        _examStartDateTime = DateTime(
          examDate.year,
          examDate.month,
          examDate.day,
          9,
          0,
        );
      } else {
        final timeParts = examTimeStr.split(':');
        if (timeParts.length == 2) {
          final hour = int.parse(timeParts[0]); // 24-hour format (0-23)
          final minute = int.parse(timeParts[1]); // 0-59
          
          // Validate hour and minute
          if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
            // Invalid time values - use default
            _examStartDateTime = DateTime(
              examDate.year,
              examDate.month,
              examDate.day,
              9,
              0,
            );
          } else {
            // Create start DateTime from examDate and examTime
            _examStartDateTime = DateTime(
              examDate.year,
              examDate.month,
              examDate.day,
              hour,
              minute,
            );
          }
        } else {
          // Default to 9:00 (09:00) if parsing fails
          _examStartDateTime = DateTime(
            examDate.year,
            examDate.month,
            examDate.day,
            9,
            0,
          );
        }
      }
      
      // Calculate end time: start time + exam duration (in minutes)
      // Example: Start 14:30 + Duration 15 minutes = End 14:45
      _examEndDateTime = _examStartDateTime!.add(Duration(minutes: widget.exam.duration));
      
      // Calculate remaining time based on actual exam end time
      // Use real-time calculation for accuracy
      _updateRemainingTime();
    } catch (e) {
      // If calculation fails, we can't determine end time
      // Timer won't start, and exam won't auto-submit
      _examStartDateTime = null;
      _examEndDateTime = null;
      _remainingTime = Duration(minutes: widget.exam.duration);
    }
  }

  /// Update remaining time using formula: ExamDuration - (CurrentTime - StartTime)
  void _updateRemainingTime() {
    if (_sessionStartTime != null) {
      // Use session-based timer: ExamDuration - (CurrentTime - StartTime)
      final now = DateTime.now();
      final elapsed = now.difference(_sessionStartTime!);
      final totalDuration = Duration(minutes: widget.exam.duration);
      
      if (elapsed >= totalDuration) {
        _remainingTime = Duration.zero;
      } else {
        _remainingTime = totalDuration - elapsed;
      }
    } else if (_examEndDateTime != null) {
      // Fallback to end-time based calculation if session not started yet
      final now = DateTime.now();
      if (now.isBefore(_examEndDateTime!)) {
        _remainingTime = _examEndDateTime!.difference(now);
      } else {
        _remainingTime = Duration.zero;
      }
    } else {
      // Default fallback
      _remainingTime = Duration(minutes: widget.exam.duration);
    }
  }

  void _startTimer() {
    // Ensure we have a valid end time or session start time
    if (_examEndDateTime == null && _sessionStartTime == null) {
      return;
    }
    
    // All exams (dummy and normal) use the same timer logic
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isExamSubmitted) {
        timer.cancel();
        return;
      }
      
      final now = DateTime.now();
      
      // Update remaining time using session-based formula
      _updateRemainingTime();
      
      // Auto-submit when remaining time reaches zero
      if (_remainingTime <= Duration.zero) {
        timer.cancel();
        _submitExam(isTimeUp: true);
        return;
      }
      
      if (mounted) {
        setState(() {
          // State updated above
        });
      }
    });
  }

  Future<void> _submitExam({bool isTimeUp = false}) async {
    // Prevent double submission
    if (_isSubmitting || _isExamSubmitted) {
      return;
    }

    // All exams (dummy and normal) use the same submission logic
    // No special handling needed

    _isSubmitting = true;
    
    // Cancel timer if still running
    if (_timer?.isActive ?? false) {
      _timer?.cancel();
    }

    // Mark time as up if timer expired
    if (isTimeUp) {
      _isTimeUp = true;
    }

    setState(() {
      _isExamSubmitted = true;
    });

    // Submit answers to database
    try {
      if (widget.studentId != null) {
        final submittedAt = DateTime.now();
        final gradeResults = await AtlasService.submitExamAnswers(
          examId: widget.exam.id.toHexString(),
          studentId: widget.studentId!,
          answers: _answers,
          submittedAt: submittedAt,
          isTimeUp: isTimeUp,
          questions: widget.questions,
        );
        
        // Show success dialog with grades
        _showSubmissionDialog(
          totalQuestions: widget.questions.length,
          answeredQuestions: _answers.length,
          isTimeUp: isTimeUp,
          gradeResults: gradeResults,
        );
      } else {
        // If no studentId, still show dialog but warn
        _showSubmissionDialog(
          totalQuestions: widget.questions.length,
          answeredQuestions: _answers.length,
          isTimeUp: isTimeUp,
          error: 'Student ID not found. Answers were not saved.',
        );
      }
    } catch (e) {
      // Show error dialog
      _showSubmissionDialog(
        totalQuestions: widget.questions.length,
        answeredQuestions: _answers.length,
        isTimeUp: isTimeUp,
        error: 'Error submitting answers: $e',
      );
    }
  }

  void _showSubmissionDialog({
    required int totalQuestions,
    required int answeredQuestions,
    required bool isTimeUp,
    String? error,
    Map<String, dynamic>? gradeResults,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(isTimeUp ? 'Time\'s Up!' : 'Exam Submitted'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isTimeUp)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Your time has expired. The exam has been automatically submitted.',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    error,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ),
              if (!isTimeUp && error == null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Your answers have been submitted and graded successfully!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              const Divider(),
              Text('Total Questions: $totalQuestions'),
              Text('Answered Questions: $answeredQuestions'),
              Text('Unanswered Questions: ${totalQuestions - answeredQuestions}'),
              if (gradeResults != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Exam Results:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Correct Answers: ${gradeResults['correctAnswers']}/${gradeResults['totalQuestions']}'),
                      Text('Score: ${gradeResults['earnedPoints']}/${gradeResults['totalPoints']} points'),
                      Text(
                        'Percentage: ${gradeResults['percentageScore'].toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (gradeResults == null && error == null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Your answers have been saved. Results will be available after grading.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Return to exam details page
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSubmit() async {
    if (_isSubmitting || _isExamSubmitted) {
      return;
    }

    final unansweredCount = widget.questions.length - _answers.length;
    final hasUnanswered = unansweredCount > 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Exam?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to submit your exam?'),
            if (hasUnanswered) ...[
              const SizedBox(height: 12),
              Text(
                'Warning: You have $unansweredCount unanswered question(s).',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 8),
            const Text('You cannot change your answers after submission.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _submitExam(isTimeUp: false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _answerQuestion(String answer) {
    if (_isExamSubmitted || _isSubmitting) return;
    
    setState(() {
      _answers[_currentQuestionIndex] = answer;
    });
  }

  void _nextQuestion() {
    if (_isExamSubmitted || _isSubmitting) return;
    
    if (_currentQuestionIndex < widget.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    }
  }

  void _previousQuestion() {
    if (_isExamSubmitted || _isSubmitting) return;
    
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
        final currentQuestion = widget.questions[_currentQuestionIndex];
        final isDisabled = _isExamSubmitted || _isSubmitting;
        // Check if time is running out (less than 5 minutes remaining)
        final isTimeRunningOut = _remainingTime.inMinutes < 5 && 
                                 _remainingTime.inMinutes > 0 && 
                                 !isDisabled;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exam.title),
      ),
      body: Column(
        children: [
          // Timer display in middle top
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
            decoration: BoxDecoration(
              color: isTimeRunningOut ? Colors.red.shade50 : Colors.blue.shade50,
              border: Border(
                bottom: BorderSide(
                  color: isTimeRunningOut ? Colors.red : Colors.blue,
                  width: 2,
                ),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Time Remaining',
                    style: TextStyle(
                      fontSize: 14,
                      color: isTimeRunningOut ? Colors.red.shade700 : Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDuration(_remainingTime),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isTimeRunningOut ? Colors.red : Colors.blue,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / widget.questions.length,
          ),
          // Question counter
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${_currentQuestionIndex + 1} of ${widget.questions.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (isTimeRunningOut && !isDisabled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Time Running Out!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Question content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentQuestion.questionText,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  ...currentQuestion.options.asMap().entries.map((entry) {
                    final optionIndex = entry.key;
                    final option = entry.value;
                    final isSelected = _answers[_currentQuestionIndex] == option;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : (isDisabled ? Colors.grey[200] : null),
                      child: InkWell(
                        onTap: isDisabled ? null : () => _answerQuestion(option),
                        child: Opacity(
                          opacity: isDisabled ? 0.6 : 1.0,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Text(
                                  '${String.fromCharCode(65 + optionIndex)}. ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Expanded(child: Text(option)),
                                if (isSelected)
                                  const Icon(Icons.check_circle, color: Colors.green),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          // Navigation buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: (isDisabled || _currentQuestionIndex == 0) 
                      ? null 
                      : _previousQuestion,
                  child: const Text('Previous'),
                ),
                ElevatedButton(
                  onPressed: (isDisabled || _currentQuestionIndex >= widget.questions.length - 1)
                      ? null
                      : _nextQuestion,
                  child: const Text('Next'),
                ),
              ],
            ),
          ),
          // Submit button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isDisabled ? null : _confirmSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDisabled ? Colors.grey : Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  _isSubmitting ? 'Submitting...' : 'Submit Exam',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 