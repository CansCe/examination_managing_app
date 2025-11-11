import 'package:flutter/material.dart';
import '../models/index.dart';
import '../services/atlas_service.dart';
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
  late Timer _timer;
  late Duration _remainingTime;
  bool _isExamSubmitted = false;
  bool _isSubmitting = false;
  bool _isTimeUp = false;

  @override
  void initState() {
    super.initState();
    _remainingTime = Duration(minutes: widget.exam.duration);
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isExamSubmitted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        if (_remainingTime.inSeconds > 0) {
          _remainingTime = _remainingTime - const Duration(seconds: 1);
        } else {
          timer.cancel();
          _submitExam(isTimeUp: true);
        }
      });
    });
  }

  Future<void> _submitExam({bool isTimeUp = false}) async {
    // Prevent double submission
    if (_isSubmitting || _isExamSubmitted) {
      return;
    }

    _isSubmitting = true;
    
    // Cancel timer if still running
    if (_timer.isActive) {
      _timer.cancel();
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
    _timer.cancel();
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
    final isTimeRunningOut = _remainingTime.inMinutes < 5 && 
                             _remainingTime.inMinutes > 0 && 
                             !isDisabled;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exam.title),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                _formatDuration(_remainingTime),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isTimeRunningOut ? Colors.red : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
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