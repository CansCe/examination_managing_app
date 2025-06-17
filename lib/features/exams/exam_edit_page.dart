import 'package:flutter/material.dart' hide State;
import 'package:flutter/material.dart' as material;
import 'package:mongo_dart/mongo_dart.dart' hide Center;
//import '../../models/teacher.dart' hide Question;
import '../../models/exam.dart';
import '../../models/question.dart';
import '../../services/mongodb_service.dart';

class ExamEditPage extends StatefulWidget {
  final Exam? exam; // If null, we're creating a new exam
  final String teacherId;

  const ExamEditPage({
    Key? key,
    this.exam,
    required this.teacherId,
  }) : super(key: key);

  @override
  material.State<ExamEditPage> createState() => _ExamEditPageState();
}

extension ObjectIdExtension on Object {
  ObjectId get id {
    if (this is Question) {
      return (this as Question).id;
    }
    if (this is Map<String, dynamic>) {
      final id = (this as Map<String, dynamic>)['_id'];
      if (id is ObjectId) return id;
      if (id is String) return ObjectId.fromHexString(id);
    }
    throw Exception('Invalid object type for id getter');
  }
}

class _ExamEditPageState extends material.State<ExamEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _durationController;
  late TextEditingController _maxStudentsController;
  late DateTime _examDate;
  late TimeOfDay _examTime;
  String _selectedSubject = '';
  String _selectedDifficulty = 'medium';
  List<Question> _selectedQuestions = [];
  List<Question> _availableQuestions = [];
  bool _isLoading = false;
  late int _duration;
  late int _maxStudents;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.exam?.title ?? '');
    _descriptionController = TextEditingController(text: widget.exam?.description ?? '');
    _durationController = TextEditingController(text: widget.exam?.duration.toString() ?? '60');
    _maxStudentsController = TextEditingController(text: widget.exam?.maxStudents.toString() ?? '30');
    if (widget.exam != null) {
      _titleController.text = widget.exam!.title;
      _descriptionController.text = widget.exam!.description;
      _selectedSubject = widget.exam!.subject;
      _selectedDifficulty = widget.exam!.difficulty;
      _examDate = widget.exam!.examDate;
      _examTime = TimeOfDay(
        hour: int.parse(widget.exam!.examTime.split(':')[0]),
        minute: int.parse(widget.exam!.examTime.split(':')[1]),
      );
      _duration = widget.exam!.duration;
      _maxStudents = widget.exam!.maxStudents;
    } else {
      // Initialize with default values for new exam
      _examDate = DateTime.now().add(const Duration(days: 1)); // Default to tomorrow
      _examTime = const TimeOfDay(hour: 9, minute: 0); // Default to 9:00 AM
      _duration = 60;
      _maxStudents = 30;
    }
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      final questions = await MongoDBService.getQuestionsBySubject(_selectedSubject);
      setState(() {
        _availableQuestions = questions;
        if (widget.exam != null) {
          // Load selected questions for existing exam
          _selectedQuestions = questions.where((q) => 
            widget.exam!.questions.contains(q.id)).toList();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading questions: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveExam() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final exam = Exam(
        id: widget.exam?.id ?? ObjectId(),
        title: _titleController.text,
        description: _descriptionController.text,
        subject: _selectedSubject,
        difficulty: _selectedDifficulty,
        examDate: _examDate,
        examTime: '${_examTime.hour.toString().padLeft(2, '0')}:${_examTime.minute.toString().padLeft(2, '0')}',
        duration: _duration,
        maxStudents: _maxStudents,
        questions: _selectedQuestions.map((q) => q.id).toList(),
        createdBy: widget.exam?.createdBy ?? ObjectId(),
        createdAt: widget.exam?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final Object success = widget.exam == null
          ? await MongoDBService.createExam(exam)
          : await MongoDBService.updateExam(exam);

      if (mounted) {
        if (success is bool && success) {
          Navigator.pop(context, true);
        } else if (success is WriteResult && success.isSuccess) {
          Navigator.pop(context, true);
        } else {
          // Handle the case where success is neither a bool nor a WriteResult or it indicates failure
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving exam: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exam == null ? 'Create New Exam' : 'Edit Exam'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveExam,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Exam Title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Please enter a title' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedSubject,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Mathematics', 'Physics', 'Chemistry', 'Biology']
                        .map((subject) => DropdownMenuItem(
                              value: subject,
                              child: Text(subject),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedSubject = value;
                          _loadQuestions();
                        });
                      }
                    },
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Please select a subject' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _durationController,
                          decoration: const InputDecoration(
                            labelText: 'Duration (minutes)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'Please enter duration';
                            }
                            if (int.tryParse(value!) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _maxStudentsController,
                          decoration: const InputDecoration(
                            labelText: 'Max Students',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'Please enter max students';
                            }
                            if (int.tryParse(value!) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: const Text('Exam Date'),
                          subtitle: Text(
                            '${_examDate.year}-${_examDate.month}-${_examDate.day}',
                          ),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _examDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setState(() => _examDate = date);
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          title: const Text('Exam Time'),
                          subtitle: Text(_examTime.format(context)),
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _examTime,
                            );
                            if (time != null) {
                              setState(() => _examTime = time);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedDifficulty,
                    decoration: const InputDecoration(
                      labelText: 'Difficulty',
                      border: OutlineInputBorder(),
                    ),
                    items: ['easy', 'medium', 'hard']
                        .map((difficulty) => DropdownMenuItem(
                              value: difficulty,
                              child: Text(difficulty.toUpperCase()),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedDifficulty = value);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Select Questions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._availableQuestions.map((question) => CheckboxListTile(
                        title: Text(question.questionText),
                        subtitle: Text(
                          'Difficulty: ${question.difficulty.toUpperCase()}',
                        ),
                        value: _selectedQuestions.contains(question),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value ?? false) {
                              _selectedQuestions.add(question);
                            } else {
                              _selectedQuestions.remove(question);
                            }
                          });
                        },
                      )),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _maxStudentsController.dispose();
    super.dispose();
  }
} 