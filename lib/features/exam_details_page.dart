import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../config/routes.dart';
import '../models/index.dart';
import '../services/index.dart';
import '../utils/pdf_export_service.dart';


class ExamDetailsPage extends StatefulWidget {
  final Exam exam;
  final String? studentId; // Student ID for submitting exam
  final UserRole? userRole; // User role to determine if delete button should be shown

  const ExamDetailsPage({
    super.key,
    required this.exam,
    this.studentId,
    this.userRole,
  });

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
  Exam? _currentExam; // Store the current exam (may be updated from API)
  Map<String, dynamic>? _examResult; // Store exam result if available (for past exams)
  Map<String, dynamic>? _examStatus; // Store exam status with student sessions (for teachers)
  Timer? _statusRefreshTimer; // Timer to refresh exam status periodically

  @override
  void initState() {
    super.initState();
    _currentExam = widget.exam; // Initialize with passed exam
    _initializeExamData(); // Load latest data and initialize
    _loadQuestions();
    
    // Start timer to check availability every minute
    _availabilityTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _checkExamAvailability();
      }
    });
    
    // For teachers/admins, load exam status and refresh periodically
    if (widget.userRole == UserRole.teacher || widget.userRole == UserRole.admin) {
      _loadExamStatus();
      // Refresh status every 5 seconds to update student timers
      _statusRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (mounted) {
          _loadExamStatus();
        }
      });
    }
  }

  /// Initialize exam data by loading latest from API, then calculating times and checking availability
  Future<void> _initializeExamData() async {
    // First, try to load latest exam data from API
    await _loadLatestExamData();
    // Then calculate start time and check availability with updated data
    _calculateExamStartTime();
    _checkExamAvailability(suppressNotification: true);
    
    // For students, always try to load their result (if they've completed the exam)
    // This allows students to view past exams and see their scores
    if (widget.userRole == UserRole.student && widget.studentId != null) {
      await _loadExamResult();
    }
  }

  /// Load exam result for the current student
  Future<void> _loadExamResult() async {
    if (widget.studentId == null) return;
    
    try {
      final exam = _currentExam ?? widget.exam;
      final examId = exam.id.toHexString();
      final api = ApiService();
      final result = await api.getExamResult(
        examId: examId,
        studentId: widget.studentId!,
      );
      api.close();
      
      if (mounted && result != null) {
        setState(() {
          _examResult = result;
        });
      }
    } catch (e) {
      // Silently fail - result might not exist yet
    }
  }

  @override
  void dispose() {
    _availabilityTimer?.cancel();
    _statusRefreshTimer?.cancel();
    super.dispose();
  }

  /// Load exam status with student sessions and timers (for teachers)
  Future<void> _loadExamStatus() async {
    if (widget.userRole != UserRole.teacher && widget.userRole != UserRole.admin) {
      return;
    }
    
    try {
      final exam = _currentExam ?? widget.exam;
      final examId = exam.id.toHexString();
      final api = ApiService();
      final status = await api.getExamStatus(examId);
      api.close();
      
      if (mounted) {
        setState(() {
          _examStatus = status;
        });
      }
    } catch (e) {
      // Silently fail - status might not be available
    }
  }

  /// Fetch the latest exam data from the API to ensure we have updated date/time
  /// If rate limited, silently falls back to using the passed exam object
  Future<void> _loadLatestExamData() async {
    try {
      final exam = _currentExam ?? widget.exam;
      final examId = exam.id.toHexString();
      final api = ApiService();
      final examData = await api.getExam(examId);
      api.close();
      
      if (examData.isNotEmpty) {
        final updatedExam = Exam.fromMap(examData);
        if (mounted) {
          setState(() {
            _currentExam = updatedExam;
          });
        }
      }
    } catch (e) {
      // If fetching fails (e.g., rate limited), continue with the passed exam object
      // Don't show error to user as the exam object from navigation should work
      // This is especially important for testing
    }
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


  void _calculateExamStartTime() {
    // Use current exam (from API) if available, otherwise use widget.exam
    final exam = _currentExam ?? widget.exam;
    
    // Dummy exams can start at any time (no start time)
    if (exam.isDummy || exam.examTime.toUpperCase() == 'NAN') {
      _examStartDateTime = null;
      return;
    }
    
    try {
      // Parse exam time (format: "HH:mm")
      final timeParts = exam.examTime.split(':');
      if (timeParts.length == 2) {
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        
        // Combine exam date and time
        _examStartDateTime = DateTime(
          exam.examDate.year,
          exam.examDate.month,
          exam.examDate.day,
          hour,
          minute,
        );
      } else {
        // Default to 9:00 AM if parsing fails
        _examStartDateTime = DateTime(
          exam.examDate.year,
          exam.examDate.month,
          exam.examDate.day,
          9,
          0,
        );
      }
    } catch (e) {
      // Default to 9:00 AM if parsing fails
      _examStartDateTime = DateTime(
        exam.examDate.year,
        exam.examDate.month,
        exam.examDate.day,
        9,
        0,
      );
    }
  }

  void _checkExamAvailability({bool suppressNotification = false}) {
    // Use current exam (from API) if available, otherwise use widget.exam
    final exam = _currentExam ?? widget.exam;
    
    // Dummy exams can always be started (only by teachers/admins)
    if (exam.isDummy || exam.examTime.toUpperCase() == 'NAN') {
      // Check if user is teacher or admin
      if (widget.userRole == UserRole.teacher || widget.userRole == UserRole.admin) {
        if (mounted) {
          setState(() {
            _canStartExam = true;
            _examAvailabilityMessage = 'Dummy exam - can be started at any time (for testing)';
          });
        }
      } else {
        // Students cannot access dummy exams
        if (mounted) {
          setState(() {
            _canStartExam = false;
            _examAvailabilityMessage = 'This exam is only available to teachers and admins';
          });
        }
      }
      return;
    }
    
    // For regular exams: Students and admins can enter
    // Check if user role is allowed for regular exams
    if (widget.userRole != UserRole.student && widget.userRole != UserRole.admin) {
      if (mounted) {
        setState(() {
          _canStartExam = false;
          _examAvailabilityMessage = 'This exam is only available to students and admins';
        });
      }
      return;
    }
    
    // If student has already completed the exam, they can view it but not start it again
    if (widget.userRole == UserRole.student && _examResult != null) {
      if (mounted) {
        setState(() {
          _canStartExam = false;
          _examAvailabilityMessage = 'You have already completed this exam. View your results below.';
        });
      }
      return;
    }
    
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

    // Calculate exam end time (start time + duration)
    final examEndDateTime = _examStartDateTime!.add(Duration(minutes: exam.duration));
    
    // Check if exam has finished (current time >= start time + duration)
    if (now.isAfter(examEndDateTime) || now.isAtSameMomentAs(examEndDateTime)) {
      if (mounted) {
        setState(() {
          _canStartExam = false;
          // If student has completed it, show different message
          if (widget.userRole == UserRole.student && _examResult != null) {
            _examAvailabilityMessage = 'This exam has finished. View your results below.';
          } else {
            _examAvailabilityMessage = 'This exam has finished and is no longer available';
          }
        });
      }
      return;
    }

    final wasAvailable = _canStartExam;
    
    // Allow entry when: start time <= current time < end time
    if (now.isAfter(_examStartDateTime!) || now.isAtSameMomentAs(_examStartDateTime!)) {
      // Check if still within exam duration window
      if (now.isBefore(examEndDateTime)) {
        if (mounted) {
          setState(() {
            _canStartExam = true;
            // Show different message if exam is in progress vs just started
            if (now.isAfter(_examStartDateTime!)) {
              final timeRemaining = examEndDateTime.difference(now);
              final minutesRemaining = timeRemaining.inMinutes;
              if (minutesRemaining > 0) {
                _examAvailabilityMessage = 'Exam is in progress. $minutesRemaining minute(s) remaining.';
              } else {
                _examAvailabilityMessage = 'Exam is now available';
              }
            } else {
              _examAvailabilityMessage = 'Exam is now available';
            }
          });
        }
      } else {
        // Should not reach here as we already checked above, but just in case
        if (mounted) {
          setState(() {
            _canStartExam = false;
            _examAvailabilityMessage = 'This exam has finished and is no longer available';
          });
        }
      }
    } else {
      // Exam hasn't started yet
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

  Future<void> _loadQuestions({int retryCount = 0}) async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);
    
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Check if exam has finished
      _checkExamAvailability();
      
      // Use current exam (from API) if available, otherwise use widget.exam
      final exam = _currentExam ?? widget.exam;
      final questions = await AtlasService.getQuestionsByIds(exam.questions);
      
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      // Check if it's a rate limit error and we can retry
      final isRateLimit = e.toString().contains('429') || 
                         e.toString().contains('rate limit') ||
                         e.toString().contains('Too many');
      
      if (isRateLimit && retryCount < maxRetries) {
        // Wait before retrying with exponential backoff
        final delay = Duration(milliseconds: retryDelay.inMilliseconds * (retryCount + 1));
        await Future.delayed(delay);
        return _loadQuestions(retryCount: retryCount + 1);
      }
      
      setState(() {
        _error = 'Error loading questions: $e';
        _isLoading = false;
      });
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
    // Use current exam (from API) if available, otherwise use widget.exam
    final exam = _currentExam ?? widget.exam;
    
    // For dummy exams, check if user is teacher or admin
    if (exam.isDummy || exam.examTime.toUpperCase() == 'NAN') {
      if (widget.userRole != UserRole.teacher && widget.userRole != UserRole.admin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This exam is only available to teachers and admins'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    }
    
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
        'exam': exam, // Use updated exam
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
          content: Text('Are you sure you want to delete "${(_currentExam ?? widget.exam).title}"? This action cannot be undone.'),
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

      final exam = _currentExam ?? widget.exam;
      final examId = exam.id.toHexString();
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
    // Use current exam (from API) if available, otherwise use widget.exam
    final exam = _currentExam ?? widget.exam;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(exam.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _loadLatestExamData();
              _calculateExamStartTime();
              _checkExamAvailability();
              _loadQuestions();
              if (widget.userRole == UserRole.teacher || widget.userRole == UserRole.admin) {
                _loadExamStatus();
              }
            },
            tooltip: 'Refresh Exam Data',
          ),
          // Export PDF button for teachers/admins
          if ((widget.userRole == UserRole.teacher || widget.userRole == UserRole.admin) && _examStatus != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _exportExamScoresToPdf,
              tooltip: 'Export Exam Scores to PDF',
            ),
          if (_canDeleteExam)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteExam,
              tooltip: 'Delete Exam',
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
                                      exam.title,
                                      style: Theme.of(context).textTheme.headlineSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      exam.description,
                                      style: Theme.of(context).textTheme.bodyLarge,
                                    ),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 8.0,
                                      runSpacing: 8.0,
                                      children: [
                                        _buildInfoChip(
                                          Icons.subject,
                                          'Subject: ${exam.subject}',
                                        ),
                                        _buildInfoChip(
                                          Icons.timer,
                                          'Duration: ${exam.duration} minutes',
                                        ),
                                        _buildInfoChip(
                                          Icons.people,
                                          'Max Students: ${exam.maxStudents}',
                                        ),
                                        _buildInfoChip(
                                          Icons.speed,
                                          'Difficulty: ${exam.difficulty}',
                                        ),
                                        _buildInfoChip(
                                          Icons.question_mark,
                                          'Questions: ${_questions.length}',
                                        ),
                                        _buildInfoChip(
                                          Icons.access_time,
                                          exam.isDummy || exam.examTime.toUpperCase() == 'NAN'
                                              ? 'Start Time: NaN (can start anytime)'
                                              : _examStartDateTime != null
                                                  ? 'Start Time: ${_examStartDateTime!.toString().split(' ')[1].substring(0, 5)}'
                                                  : 'Start Time: N/A',
                                        ),
                                        if (_examStartDateTime != null)
                                          _buildInfoChip(
                                            Icons.calendar_today,
                                            'Date: ${exam.examDate.toString().split(' ')[0]}',
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
                                    // Exam Status and Student Sessions (for teachers/admins)
                                    if ((widget.userRole == UserRole.teacher || widget.userRole == UserRole.admin) && _examStatus != null)
                                      Card(
                                        margin: const EdgeInsets.only(top: 16, bottom: 16),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.info_outline, color: Colors.blue),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Exam Status',
                                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),
                                              // Current Exam State
                                              Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: _getStateColor(_examStatus!['examState'] as String).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: _getStateColor(_examStatus!['examState'] as String),
                                                    width: 2,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      _getStateIcon(_examStatus!['examState'] as String),
                                                      color: _getStateColor(_examStatus!['examState'] as String),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'State: ${_formatExamState(_examStatus!['examState'] as String)}',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: _getStateColor(_examStatus!['examState'] as String),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              // Student Sessions
                                              Text(
                                                'Student Sessions (${(_examStatus!['studentSessions'] as List).length} students)',
                                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              if ((_examStatus!['studentSessions'] as List).isEmpty)
                                                const Padding(
                                                  padding: EdgeInsets.all(16.0),
                                                  child: Text('No students assigned to this exam.'),
                                                )
                                              else
                                                ...(_examStatus!['studentSessions'] as List).map((session) {
                                                  return _buildStudentSessionCard(session);
                                                }),
                                            ],
                                          ),
                                        ),
                                      ),
                                    // Display exam result if available (for students who completed the exam)
                                    if (_examResult != null && widget.userRole == UserRole.student)
                                      Card(
                                        color: Colors.green.withOpacity(0.1),
                                        margin: const EdgeInsets.only(bottom: 16),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.check_circle, color: Colors.green[700]),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Exam Completed',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.green[900],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'You have completed this exam. Your results are shown below.',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.green[800],
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              const Divider(),
                                              const SizedBox(height: 16),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                children: [
                                                  _buildResultStat(
                                                    'Score',
                                                    '${_examResult!['earnedPoints'] ?? 0}/${_examResult!['totalPoints'] ?? 0}',
                                                    Icons.star,
                                                    Colors.amber,
                                                  ),
                                                  _buildResultStat(
                                                    'Correct',
                                                    '${_examResult!['correctAnswers'] ?? 0}/${_examResult!['totalQuestions'] ?? 0}',
                                                    Icons.check_circle,
                                                    Colors.green,
                                                  ),
                                                  _buildResultStat(
                                                    'Percentage',
                                                    '${((_examResult!['percentageScore'] ?? 0) as num).toStringAsFixed(1)}%',
                                                    Icons.percent,
                                                    Colors.blue,
                                                  ),
                                                ],
                                              ),
                                              if (_examResult!['submittedAt'] != null)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 12.0),
                                                  child: Text(
                                                    'Submitted: ${_formatSubmittedDate(_examResult!['submittedAt'])}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[700],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    // Show message if student hasn't completed a past exam
                                    if (_examResult == null && 
                                        widget.userRole == UserRole.student && 
                                        _examAvailabilityMessage.contains('finished'))
                                      Card(
                                        color: Colors.orange.withOpacity(0.1),
                                        margin: const EdgeInsets.only(bottom: 16),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Row(
                                            children: [
                                              Icon(Icons.info_outline, color: Colors.orange[700]),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  'This exam has ended. You did not complete this exam.',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.orange[900],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                    // Only show Start Exam button for students, not teachers
                                    if (widget.userRole == UserRole.student || widget.userRole == UserRole.admin)
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
                                    if (_examAvailabilityMessage.contains('finished') && 
                                        !(_examResult != null && widget.userRole == UserRole.student))
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
                tooltip: 'Delete Exam',
                child: const Icon(Icons.delete, color: Colors.white),
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

  Widget _buildResultStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  String _formatSubmittedDate(dynamic dateValue) {
    try {
      if (dateValue is String) {
        final date = DateTime.parse(dateValue);
        return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  Color _getStateColor(String state) {
    switch (state) {
      case 'scheduled':
        return Colors.blue;
      case 'in_progress':
        return Colors.green;
      case 'finished':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  IconData _getStateIcon(String state) {
    switch (state) {
      case 'scheduled':
        return Icons.schedule;
      case 'in_progress':
        return Icons.play_circle_outline;
      case 'finished':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  String _formatExamState(String state) {
    switch (state) {
      case 'scheduled':
        return 'Scheduled';
      case 'in_progress':
        return 'In Progress';
      case 'finished':
        return 'Finished';
      default:
        return state;
    }
  }

  String _formatSessionStatus(String status) {
    switch (status) {
      case 'not_started':
        return 'Not Started';
      case 'in_progress':
        return 'In Progress';
      case 'time_up':
        return 'Time Up';
      case 'finished':
        return 'Finished';
      default:
        return status;
    }
  }

  String _formatDurationFromSeconds(int? seconds) {
    if (seconds == null || seconds <= 0) return '00:00:00';
    final duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final secs = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$secs';
  }

  Widget _buildStudentSessionCard(Map<String, dynamic> session) {
    final status = session['sessionStatus'] as String;
    final remainingTime = session['remainingTime'] as int?;
    final isInProgress = status == 'in_progress';
    final isTimeUp = status == 'time_up';
    final isCompleted = status == 'completed';
    final score = session['score'] as int?;
    final percentageScore = session['percentageScore'] as double?;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isCompleted
          ? Colors.blue.shade50
          : isTimeUp 
              ? Colors.red.shade50 
              : isInProgress 
                  ? Colors.green.shade50 
                  : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session['studentName'] as String? ?? 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if ((session['studentRollNumber'] as String?)?.isNotEmpty == true)
                    Text(
                      'Roll: ${session['studentRollNumber']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isCompleted 
                            ? Icons.check_circle 
                            : isInProgress 
                                ? Icons.play_circle 
                                : Icons.pause_circle,
                        size: 16,
                        color: isCompleted 
                            ? Colors.blue 
                            : isInProgress 
                                ? Colors.green 
                                : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCompleted ? 'Done Exam' : _formatSessionStatus(status),
                        style: TextStyle(
                          fontSize: 14,
                          color: isCompleted 
                              ? Colors.blue 
                              : isTimeUp 
                                  ? Colors.red 
                                  : (isInProgress ? Colors.green : Colors.grey),
                          fontWeight: (isInProgress || isCompleted) ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isCompleted && score != null && percentageScore != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Score',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$score',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '${percentageScore.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else if (isInProgress && remainingTime != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: remainingTime < 300 ? Colors.red.shade100 : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: remainingTime < 300 ? Colors.red : Colors.blue,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Time Remaining',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDurationFromSeconds(remainingTime),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: remainingTime < 300 ? Colors.red : Colors.blue,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Export exam scores to PDF
  Future<void> _exportExamScoresToPdf() async {
    if (_examStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exam status not available. Please refresh.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final exam = _currentExam ?? widget.exam;
      final examId = exam.id.toHexString();

      // Get all exam results
      final api = ApiService();
      final examResults = await api.getExamResults(examId);
      api.close();

      // Get student sessions from exam status
      final studentSessions = (_examStatus!['studentSessions'] as List)
          .map((s) => s as Map<String, dynamic>)
          .toList();

      // Export to PDF
      final filePath = await PdfExportService.exportExamScores(
        examTitle: exam.title,
        examSubject: exam.subject,
        examDate: exam.examDate,
        examTime: exam.examTime,
        examDuration: exam.duration,
        studentSessions: studentSessions,
        examResults: examResults,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF exported successfully to:\n$filePath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
} 