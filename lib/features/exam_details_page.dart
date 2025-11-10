import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../config/routes.dart';
import '../models/index.dart';
import '../services/index.dart';


class ExamDetailsPage extends StatefulWidget {
  final Exam exam;
  final String? studentId; // Student ID for submitting exam
  final UserRole? userRole; // User role to determine if delete button should be shown

  const ExamDetailsPage({
    Key? key,
    required this.exam,
    this.studentId,
    this.userRole,
  }) : super(key: key);

  @override
  State<ExamDetailsPage> createState() => _ExamDetailsPageState();
}

class _ExamDetailsPageState extends State<ExamDetailsPage> {
  List<Question> _questions = [];
  bool _isLoading = true;
  String? _error;
  DateTime? _examStartDateTime;
  bool _canStartExam = false;
  String _examAvailabilityMessage = '';
  Timer? _availabilityTimer;
  bool _shouldShowAvailabilityNotification = false;

  @override
  void initState() {
    super.initState();
    _calculateExamStartTime();
    _checkExamAvailability(suppressNotification: true);
    _loadQuestions();
    
    // Start timer to check availability every minute
    _availabilityTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _checkExamAvailability();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Show notification after widget tree is built
    if (_shouldShowAvailabilityNotification) {
      _shouldShowAvailabilityNotification = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Exam is now available! You can start taking it.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _availabilityTimer?.cancel();
    super.dispose();
  }

  void _calculateExamStartTime() {
    try {
      // Parse exam time (format: "HH:mm")
      final timeParts = widget.exam.examTime.split(':');
      if (timeParts.length == 2) {
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        
        // Combine exam date and time
        _examStartDateTime = DateTime(
          widget.exam.examDate.year,
          widget.exam.examDate.month,
          widget.exam.examDate.day,
          hour,
          minute,
        );
      } else {
        // Default to 9:00 AM if parsing fails
        _examStartDateTime = DateTime(
          widget.exam.examDate.year,
          widget.exam.examDate.month,
          widget.exam.examDate.day,
          9,
          0,
        );
      }
    } catch (e) {
      // Default to 9:00 AM if parsing fails
      _examStartDateTime = DateTime(
        widget.exam.examDate.year,
        widget.exam.examDate.month,
        widget.exam.examDate.day,
        9,
        0,
      );
    }
  }

  void _checkExamAvailability({bool suppressNotification = false}) {
    final now = DateTime.now();
    
    if (_examStartDateTime == null) {
      if (mounted) {
        setState(() {
          _canStartExam = false;
          _examAvailabilityMessage = 'Unable to determine exam start time';
        });
      }
      return;
    }

    // Calculate exam end time
    final examEndDateTime = _examStartDateTime!.add(Duration(minutes: widget.exam.duration));
    
    // Check if exam has finished
    if (now.isAfter(examEndDateTime)) {
      if (mounted) {
        setState(() {
          _canStartExam = false;
          _examAvailabilityMessage = 'This exam has finished and is no longer available';
        });
      }
      return;
    }

    final wasAvailable = _canStartExam;
    
    if (now.isAfter(_examStartDateTime!) || now.isAtSameMomentAs(_examStartDateTime!)) {
      if (mounted) {
        setState(() {
          _canStartExam = true;
          _examAvailabilityMessage = 'Exam is now available';
        });
      }
    } else {
      final timeUntil = _examStartDateTime!.difference(now);
      String message;
      
      if (timeUntil.inDays > 0) {
        message = 'Exam starts in ${timeUntil.inDays} day(s) and ${(timeUntil.inHours % 24)} hour(s)';
      } else if (timeUntil.inHours > 0) {
        message = 'Exam starts in ${timeUntil.inHours} hour(s) and ${(timeUntil.inMinutes % 60)} minute(s)';
      } else {
        message = 'Exam starts in ${timeUntil.inMinutes} minute(s)';
      }
      
      if (mounted) {
        setState(() {
          _canStartExam = false;
          _examAvailabilityMessage = message;
        });
      }
    }
    
    // If exam just became available, show a notification (but not during initState)
    if (!wasAvailable && _canStartExam && mounted && !suppressNotification) {
      // Use post-frame callback to ensure context is available
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Exam is now available! You can start taking it.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    } else if (!wasAvailable && _canStartExam && suppressNotification) {
      // Mark that we should show notification after widget is built
      _shouldShowAvailabilityNotification = true;
    }
  }

  Future<void> _loadQuestions() async {
    try {
      
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Check if exam has finished
      _checkExamAvailability();
      
      final questions = await AtlasService.getQuestionsByIds(widget.exam.questions);
      
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading questions: $e';
        _isLoading = false;
      });
      //print('Error loading questions: $e');
    }
  }

  /// Randomize questions and their options for each student to prevent cheating
  List<Question> _randomizeQuestions(List<Question> questions) {
    final random = Random();
    final randomizedQuestions = List<Question>.from(questions);
    
    // Shuffle the questions list
    randomizedQuestions.shuffle(random);
    
    // For each question, shuffle options if it's a multiple-choice question
    for (int i = 0; i < randomizedQuestions.length; i++) {
      final question = randomizedQuestions[i];
      
      // Only shuffle options for multiple-choice questions (type 'option' or 'multiple_choice')
      if (question.type == 'option' || question.type == 'multiple_choice') {
        if (question.options.isNotEmpty) {
          // Store the correct answer string before shuffling
          final correctAnswerText = question.correctAnswer;
          
          // Create a copy of options with their original indices
          final optionsWithIndices = question.options.asMap().entries.toList();
          
          // Shuffle the options
          optionsWithIndices.shuffle(random);
          
          // Extract the shuffled options
          final shuffledOptions = optionsWithIndices.map((e) => e.value).toList();
          
          // Find the new index of the correct answer
          final newCorrectIndex = shuffledOptions.indexOf(correctAnswerText);
          
          // Create a new question with shuffled options and updated correctOptionIndex
          randomizedQuestions[i] = question.copyWith(
            options: shuffledOptions,
            correctOptionIndex: newCorrectIndex >= 0 ? newCorrectIndex : 0,
          );
        }
      }
    }
    
    return randomizedQuestions;
  }

  void _startExam() {
    // Re-check availability before starting
    _checkExamAvailability();
    
    if (!_canStartExam) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_examAvailabilityMessage),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No questions available for this exam.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Randomize questions and options for each student
    final randomizedQuestions = _randomizeQuestions(_questions);

    Navigator.pushNamed(
      context,
      AppRoutes.examination,
      arguments: {
        'exam': widget.exam,
        'questions': randomizedQuestions,
        'studentId': widget.studentId,
      },
    );
  }

  Future<void> _deleteExam() async {
    // Show confirmation dialog
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Exam'),
          content: Text('Are you sure you want to delete "${widget.exam.title}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmDelete != true) {
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final examId = widget.exam.id.toHexString();
      final success = await AtlasService.deleteExam(examId);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exam deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate back
        Navigator.of(context).pop(true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete exam'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting exam: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool get _canDeleteExam {
    return widget.userRole == UserRole.admin || widget.userRole == UserRole.teacher;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exam.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQuestions,
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadQuestions,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Exam Details
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.exam.title,
                                      style: Theme.of(context).textTheme.headlineSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      widget.exam.description,
                                      style: Theme.of(context).textTheme.bodyLarge,
                                    ),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 8.0,
                                      runSpacing: 8.0,
                                      children: [
                                        _buildInfoChip(
                                          Icons.subject,
                                          'Subject: ${widget.exam.subject}',
                                        ),
                                        _buildInfoChip(
                                          Icons.timer,
                                          'Duration: ${widget.exam.duration} minutes',
                                        ),
                                        _buildInfoChip(
                                          Icons.people,
                                          'Max Students: ${widget.exam.maxStudents}',
                                        ),
                                        _buildInfoChip(
                                          Icons.speed,
                                          'Difficulty: ${widget.exam.difficulty}',
                                        ),
                                        _buildInfoChip(
                                          Icons.question_mark,
                                          'Questions: ${_questions.length}',
                                        ),
                                        if (_examStartDateTime != null)
                                          _buildInfoChip(
                                            Icons.access_time,
                                            'Start Time: ${_examStartDateTime!.toString().split(' ')[1].substring(0, 5)}',
                                          ),
                                        if (_examStartDateTime != null)
                                          _buildInfoChip(
                                            Icons.calendar_today,
                                            'Date: ${widget.exam.examDate.toString().split(' ')[0]}',
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    // Exam availability status
                                    if (!_canStartExam && _examAvailabilityMessage.isNotEmpty)
                                      Card(
                                        color: _examAvailabilityMessage.contains('finished') || 
                                               _examAvailabilityMessage.contains('no longer available')
                                            ? Colors.red.withOpacity(0.1)
                                            : Colors.orange.withOpacity(0.1),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Row(
                                            children: [
                                              Icon(
                                                _examAvailabilityMessage.contains('finished') || 
                                                _examAvailabilityMessage.contains('no longer available')
                                                    ? Icons.block
                                                    : Icons.access_time,
                                                color: _examAvailabilityMessage.contains('finished') || 
                                                       _examAvailabilityMessage.contains('no longer available')
                                                    ? Colors.red[700]
                                                    : Colors.orange[700],
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  _examAvailabilityMessage,
                                                  style: TextStyle(
                                                    color: _examAvailabilityMessage.contains('finished') || 
                                                           _examAvailabilityMessage.contains('no longer available')
                                                        ? Colors.red[900]
                                                        : Colors.orange[900],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (_canStartExam && _examAvailabilityMessage.isNotEmpty)
                                      Card(
                                        color: Colors.green.withOpacity(0.1),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Row(
                                            children: [
                                              Icon(Icons.check_circle, color: Colors.green[700]),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  _examAvailabilityMessage,
                                                  style: TextStyle(
                                                    color: Colors.green[900],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _canStartExam && !_isLoading && _questions.isNotEmpty
                                            ? _startExam
                                            : null,
                                        icon: const Icon(Icons.play_arrow),
                                        label: const Text('Start Exam'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          disabledBackgroundColor: Colors.grey,
                                        ),
                                      ),
                                    ),
                                    if (!_canStartExam && !_examAvailabilityMessage.contains('finished'))
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          'Please wait until the exam start time to begin.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontStyle: FontStyle.italic,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    if (_examAvailabilityMessage.contains('finished'))
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          'This exam is no longer available. The exam time has ended.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red[700],
                                            fontStyle: FontStyle.italic,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
          // Delete button in bottom right (only for admin and teacher)
          if (_canDeleteExam)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                onPressed: _isLoading ? null : _deleteExam,
                backgroundColor: Colors.red,
                child: const Icon(Icons.delete, color: Colors.white),
                tooltip: 'Delete Exam',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
} 