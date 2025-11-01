import 'package:flutter/material.dart';
import '../config/routes.dart';
import '../models/exam.dart';
import '../models/question.dart';
import '../services/atlas_service.dart';


class ExamDetailsPage extends StatefulWidget {
  final Exam exam;
  final String? studentId; // Student ID for submitting exam

  const ExamDetailsPage({
    Key? key,
    required this.exam,
    this.studentId,
  }) : super(key: key);

  @override
  State<ExamDetailsPage> createState() => _ExamDetailsPageState();
}

class _ExamDetailsPageState extends State<ExamDetailsPage> {
  List<Question> _questions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      
      setState(() {
        _isLoading = true;
        _error = null;
      });

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

  void _startExam() {
    Navigator.pushNamed(
      context,
      AppRoutes.examination,
      arguments: {
        'exam': widget.exam,
        'questions': _questions,
        'studentId': widget.studentId,
      },
    );
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
      body: _isLoading
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
                                  ],
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _startExam,
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Start Exam'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
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