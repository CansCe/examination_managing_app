import 'package:flutter/material.dart' ;
import 'package:flutter/material.dart' as material;
import 'package:mongo_dart/mongo_dart.dart'  hide Center;
import '../../models/exam.dart';
import '../../models/question.dart';
import '../../services/mongodb_service.dart';
import '../../utils/dialog_helper.dart';
import '../../config/routes.dart';
import '../questions/question_edit_page.dart';

class ExamEditPage extends StatefulWidget {
  final String? examId; // If null, we're creating a new exam
  final String teacherId;

  const ExamEditPage({
    Key? key,
    this.examId,
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
  late TextEditingController _searchController;
  late DateTime _examDate;
  late TimeOfDay _examTime;
  late String? _selectedSubject;
  String _selectedDifficulty = 'medium';
  String? _questionFilterSubject;
  String? _questionFilterDifficulty;
  List<Question> _selectedQuestions = [];
  List<Question> _availableQuestions = [];
  List<Question> _filteredQuestions = [];
  bool _isLoading = false;
  late int _duration;
  late int _maxStudents;
  Exam? _exam; // Store loaded exam if editing

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _durationController = TextEditingController();
    _maxStudentsController = TextEditingController();
    _searchController = TextEditingController();
    _searchController.addListener(_filterQuestions);
    if (widget.examId != null) {
      _fetchExamAndInit();
    } else {
      _initForNewExam();
      _loadQuestions();
    }
  }

  Future<void> _fetchExamAndInit() async {
    setState(() => _isLoading = true);
    try {
      final exam = await MongoDBService.getExamById(ObjectId.fromHexString(widget.examId!));
      if (exam != null) {
        _exam = exam;
        _titleController.text = exam.title;
        _descriptionController.text = exam.description;
        _durationController.text = exam.duration.toString();
        _maxStudentsController.text = exam.maxStudents.toString();
        _selectedSubject = exam.subject;
        _selectedDifficulty = exam.difficulty;
        _examDate = exam.examDate;
        _examTime = TimeOfDay(
          hour: int.parse(exam.examTime.split(':')[0]),
          minute: int.parse(exam.examTime.split(':')[1]),
        );
        _duration = exam.duration;
        _maxStudents = exam.maxStudents;
      } else {
        _initForNewExam();
      }
      await _loadQuestions();
    } catch (e) {
      _initForNewExam();
      if (mounted) {
        DialogHelper.showErrorDialog(
          context: context,
          title: 'Error Loading Exam',
          message: 'An error occurred while loading the exam: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initForNewExam() {
    _exam = null;
    _titleController.text = '';
    _descriptionController.text = '';
    _durationController.text = '60';
    _maxStudentsController.text = '30';
    _selectedSubject = null;
    _selectedDifficulty = 'medium';
    _examDate = DateTime.now().add(const Duration(days: 1));
    _examTime = const TimeOfDay(hour: 9, minute: 0);
    _duration = 60;
    _maxStudents = 30;
    _selectedQuestions = [];
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      // Load all questions from the collection
      final questions = await MongoDBService.getAllQuestions();
      setState(() {
        _availableQuestions = questions;
        _filteredQuestions = questions;
        if (_exam != null) {
          _selectedQuestions = questions.where((q) => _exam!.questions.contains(q.id)).toList();
        }
        _filterQuestions(); // Apply initial filters
      });
    } catch (e) {
      if (mounted) {
        DialogHelper.showErrorDialog(
          context: context,
          title: 'Error Loading Questions',
          message: 'An error occurred while loading questions: $e',
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterQuestions() {
    final searchQuery = _searchController.text.toLowerCase();
    setState(() {
      _filteredQuestions = _availableQuestions.where((question) {
        // Search filter
        final matchesSearch = searchQuery.isEmpty ||
            question.questionText.toLowerCase().contains(searchQuery) ||
            question.topic.toLowerCase().contains(searchQuery) ||
            question.subject.toLowerCase().contains(searchQuery);

        // Subject filter
        final matchesSubject = _questionFilterSubject == null ||
            _questionFilterSubject!.isEmpty ||
            question.subject == _questionFilterSubject;

        // Difficulty filter
        final matchesDifficulty = _questionFilterDifficulty == null ||
            _questionFilterDifficulty!.isEmpty ||
            question.difficulty == _questionFilterDifficulty;

        return matchesSearch && matchesSubject && matchesDifficulty;
      }).toList();
    });
  }

  Future<void> _saveExam() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final exam = Exam(
        id: _exam?.id ?? ObjectId(),
        title: _titleController.text,
        description: _descriptionController.text,
        subject: _selectedSubject!,
        difficulty: _selectedDifficulty,
        examDate: _examDate,
        examTime: '${_examTime.hour.toString().padLeft(2, '0')}:${_examTime.minute.toString().padLeft(2, '0')}',
        duration: int.tryParse(_durationController.text) ?? 60,
        maxStudents: int.tryParse(_maxStudentsController.text) ?? 30,
        questions: _selectedQuestions.map((q) => q.id).toList(),
        createdBy: _exam?.createdBy ?? ObjectId.fromHexString(widget.teacherId),
        createdAt: _exam?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final Object success = _exam == null
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
        DialogHelper.showErrorDialog(
          context: context,
          title: 'Error Saving Exam',
          message: 'An error occurred while saving the exam: $e',
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
    // Guard: Only teachers can access this page (teacherId must be provided)
    if (widget.teacherId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: Colors.red,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Access Denied: Only teachers can create or edit exams.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.red),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_exam == null ? 'Create New Exam' : 'Edit Exam'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveExam,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'import':
                  _importQuestionBank();
                  break;
                case 'new':
                  _createNewQuestion();
                  break;
                case 'edit':
                  _editQuestion();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: Text('Import Question Bank'),
              ),
              const PopupMenuItem(
                value: 'new',
                child: Text('New Question'),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: Text('Edit Question'),
              ),
            ],
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
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Select a subject'),
                      ),
                      ...['Mathematics', 'Physics', 'Chemistry', 'Biology']
                          .map((subject) => DropdownMenuItem(
                                value: subject,
                                child: Text(subject),
                              ))
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedSubject = value;
                        _loadQuestions();
                      });
                    },
                    validator: (value) => value == null || value.isEmpty ? 'Please select a subject' : null,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Questions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_selectedQuestions.length} selected',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Search and filter section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              labelText: 'Search Questions',
                              hintText: 'Search by question text, topic, or subject',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _questionFilterSubject,
                                  decoration: const InputDecoration(
                                    labelText: 'Filter by Subject',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('All Subjects'),
                                    ),
                                    ...['Mathematics', 'Physics', 'Chemistry', 'Biology']
                                        .map((subject) => DropdownMenuItem(
                                              value: subject,
                                              child: Text(subject),
                                            ))
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _questionFilterSubject = value;
                                      _filterQuestions();
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _questionFilterDifficulty,
                                  decoration: const InputDecoration(
                                    labelText: 'Filter by Difficulty',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('All Difficulties'),
                                    ),
                                    ...['easy', 'medium', 'hard']
                                        .map((difficulty) => DropdownMenuItem(
                                              value: difficulty,
                                              child: Text(difficulty.toUpperCase()),
                                            ))
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _questionFilterDifficulty = value;
                                      _filterQuestions();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Selected questions summary
                  if (_selectedQuestions.isNotEmpty) ...[
                    Card(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Selected Questions (${_selectedQuestions.length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _selectedQuestions.clear();
                                    });
                                  },
                                  icon: const Icon(Icons.clear_all, size: 18),
                                  label: const Text('Clear All'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _selectedQuestions.map((q) {
                                return Chip(
                                  label: Text(
                                    q.questionText.length > 30
                                        ? '${q.questionText.substring(0, 30)}...'
                                        : q.questionText,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onDeleted: () {
                                    setState(() {
                                      _selectedQuestions.remove(q);
                                    });
                                  },
                                  deleteIcon: const Icon(Icons.close, size: 18),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Questions list
                  _filteredQuestions.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text(
                              'No questions found. Try adjusting your filters or create a new question.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : Column(
                          children: _filteredQuestions.map((question) {
                            final isSelected = _selectedQuestions.any((q) => q.id == question.id);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: isSelected ? 4 : 1,
                              color: isSelected
                                  ? Theme.of(context).primaryColor.withOpacity(0.1)
                                  : null,
                              child: CheckboxListTile(
                                value: isSelected,
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value ?? false) {
                                      if (!_selectedQuestions.any((q) => q.id == question.id)) {
                                        _selectedQuestions.add(question);
                                      }
                                    } else {
                                      _selectedQuestions.removeWhere((q) => q.id == question.id);
                                    }
                                  });
                                },
                                title: Text(
                                  question.questionText,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Chip(
                                          label: Text(question.subject),
                                          avatar: const Icon(Icons.book, size: 16),
                                          labelStyle: const TextStyle(fontSize: 12),
                                        ),
                                        const SizedBox(width: 8),
                                        Chip(
                                          label: Text(question.difficulty.toUpperCase()),
                                          avatar: const Icon(Icons.trending_up, size: 16),
                                          labelStyle: const TextStyle(fontSize: 12),
                                        ),
                                        const SizedBox(width: 8),
                                        Chip(
                                          label: Text('${question.points} pts'),
                                          avatar: const Icon(Icons.star, size: 16),
                                          labelStyle: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    if (question.topic.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Topic: ${question.topic}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ],
                                ),
                                secondary: IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _editQuestion(question),
                                  tooltip: 'Edit Question',
                                ),
                              ),
                            );
                          }).toList(),
                        ),
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
    _searchController.dispose();
    super.dispose();
  }

  // --- Question Management Methods ---
  void _importQuestionBank() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import Question Bank feature coming soon')),
    );
  }

  Future<void> _createNewQuestion() async {
    // Only teachers can create questions
    if (widget.teacherId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Denied: Only teachers can create questions.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionEditPage(
          questionId: null,
          teacherId: widget.teacherId,
          examId: _exam?.id,
        ),
      ),
    );

    // Reload questions if a new question was created
    if (result == true && mounted) {
      _loadQuestions();
    }
  }

  Future<void> _editQuestion(Question question) async {
    // Only teachers can edit questions
    if (widget.teacherId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Denied: Only teachers can edit questions.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionEditPage(
          questionId: question.id.toHexString(),
          teacherId: widget.teacherId,
          examId: _exam?.id,
        ),
      ),
    );

    // Reload questions if the question was updated
    if (result == true && mounted) {
      _loadQuestions();
    }
  }
} 