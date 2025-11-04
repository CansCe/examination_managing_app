import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' hide State, Center;
import '../../models/index.dart';
import '../../services/mongodb_service.dart';
import '../../utils/dialog_helper.dart';

class QuestionEditPage extends StatefulWidget {
  final String? questionId; // If null, we're creating a new question
  final String teacherId;
  final ObjectId? examId; // Optional: if provided, link question to exam

  const QuestionEditPage({
    Key? key,
    this.questionId,
    required this.teacherId,
    this.examId,
  }) : super(key: key);

  @override
  State<QuestionEditPage> createState() => _QuestionEditPageState();
}

class _QuestionEditPageState extends State<QuestionEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _questionTextController;
  late List<TextEditingController> _optionControllers;
  late TextEditingController _topicController;
  late TextEditingController _pointsController;
  late TextEditingController _fillInAnswerController;
  
  String? _selectedSubject;
  String _selectedDifficulty = 'medium';
  String _questionType = 'multiple_choice'; // 'multiple_choice' or 'fill_in'
  int _correctOptionIndex = 0;
  bool _isLoading = false;
  Question? _question; // Store loaded question if editing
  int _points = 1;

  @override
  void initState() {
    super.initState();
    _questionTextController = TextEditingController();
    _optionControllers = List.generate(4, (_) => TextEditingController());
    _topicController = TextEditingController();
    _pointsController = TextEditingController(text: '1');
    _fillInAnswerController = TextEditingController();
    
    if (widget.questionId != null) {
      _fetchQuestionAndInit();
    } else {
      _initForNewQuestion();
    }
  }

  Future<void> _fetchQuestionAndInit() async {
    setState(() => _isLoading = true);
    try {
      final question = await MongoDBService.getQuestionById(
        ObjectId.fromHexString(widget.questionId!),
      );
      if (question != null) {
        _question = question;
        _questionTextController.text = question.questionText;
        _topicController.text = question.topic;
        _selectedSubject = question.subject;
        _selectedDifficulty = question.difficulty;
        _questionType = question.type;
        _correctOptionIndex = question.correctOptionIndex;
        _points = question.points;
        _pointsController.text = question.points.toString();
        
        // Initialize based on question type
        if (_questionType == 'fill_in') {
          _fillInAnswerController.text = question.correctAnswer;
        } else {
          // Initialize option controllers
          for (int i = 0; i < 4; i++) {
            if (i < question.options.length) {
              _optionControllers[i].text = question.options[i];
            } else {
              _optionControllers[i].text = '';
            }
          }
        }
      } else {
        _initForNewQuestion();
        if (mounted) {
          DialogHelper.showErrorDialog(
            context: context,
            title: 'Question Not Found',
            message: 'The question you are trying to edit does not exist.',
          );
        }
      }
    } catch (e) {
      _initForNewQuestion();
      if (mounted) {
        DialogHelper.showErrorDialog(
          context: context,
          title: 'Error Loading Question',
          message: 'An error occurred while loading the question: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initForNewQuestion() {
    _question = null;
    _questionTextController.text = '';
    _topicController.text = '';
    _pointsController.text = '1';
    _fillInAnswerController.text = '';
    _selectedSubject = null;
    _selectedDifficulty = 'medium';
    _questionType = 'multiple_choice';
    _correctOptionIndex = 0;
    _points = 1;
    for (var controller in _optionControllers) {
      controller.text = '';
    }
  }

  Future<void> _saveQuestion() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate based on question type
    if (_questionType == 'multiple_choice') {
      // Validate that all options are filled
      for (int i = 0; i < _optionControllers.length; i++) {
        if (_optionControllers[i].text.trim().isEmpty) {
          DialogHelper.showErrorDialog(
            context: context,
            title: 'Validation Error',
            message: 'Please fill in all 4 options.',
          );
          return;
        }
      }
    } else if (_questionType == 'fill_in') {
      // Validate fill-in answer
      if (_fillInAnswerController.text.trim().isEmpty) {
        DialogHelper.showErrorDialog(
          context: context,
          title: 'Validation Error',
          message: 'Please enter the correct answer.',
        );
        return;
      }
    }

    // Validate subject selection
    if (_selectedSubject == null || _selectedSubject!.isEmpty) {
      DialogHelper.showErrorDialog(
        context: context,
        title: 'Validation Error',
        message: 'Please select a subject.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final questionText = _questionTextController.text.trim();
      final topic = _topicController.text.trim();
      final points = int.tryParse(_pointsController.text) ?? 1;

      // Prepare options and correct answer based on type
      final List<String> options;
      final String correctAnswer;
      final int correctOptionIndex;

      if (_questionType == 'multiple_choice') {
        options = _optionControllers.map((c) => c.text.trim()).toList();
        correctAnswer = options[_correctOptionIndex];
        correctOptionIndex = _correctOptionIndex;
      } else {
        // For fill-in questions, use empty options and store answer in correctAnswer
        options = [];
        correctAnswer = _fillInAnswerController.text.trim();
        correctOptionIndex = 0;
      }

      final question = Question(
        id: _question?.id ?? ObjectId(),
        text: questionText,
        questionText: questionText,
        type: _questionType,
        subject: _selectedSubject!,
        topic: topic,
        difficulty: _selectedDifficulty,
        points: points,
        examId: widget.examId ?? _question?.examId ?? ObjectId(),
        createdBy: _question?.createdBy ?? ObjectId.fromHexString(widget.teacherId),
        options: options,
        correctAnswer: correctAnswer,
        correctOptionIndex: correctOptionIndex,
        createdAt: _question?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success = _question == null
          ? await MongoDBService.createQuestion(question)
          : await MongoDBService.updateQuestion(question);

      if (mounted) {
        if (success) {
          Navigator.pop(context, true); // Return true to indicate success
        } else {
          DialogHelper.showErrorDialog(
            context: context,
            title: 'Error Saving Question',
            message: 'An error occurred while saving the question.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        DialogHelper.showErrorDialog(
          context: context,
          title: 'Error Saving Question',
          message: 'An error occurred while saving the question: $e',
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
              'Access Denied: Only teachers can create or edit questions.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.red),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_question == null ? 'Create New Question' : 'Edit Question'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save',
            onPressed: _isLoading ? null : _saveQuestion,
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
                  // Subject Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedSubject,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                      helperText: 'Required',
                    ),
                    items: ['Mathematics', 'Physics', 'Chemistry', 'Biology']
                        .map((subject) => DropdownMenuItem(
                              value: subject,
                              child: Text(subject),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSubject = value;
                      });
                    },
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Please select a subject' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // Topic Text Field
                  TextFormField(
                    controller: _topicController,
                    decoration: const InputDecoration(
                      labelText: 'Topic',
                      border: OutlineInputBorder(),
                      helperText: 'Required',
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Please enter a topic' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // Question Type Selector
                  DropdownButtonFormField<String>(
                    value: _questionType,
                    decoration: const InputDecoration(
                      labelText: 'Question Type',
                      border: OutlineInputBorder(),
                      helperText: 'Required',
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'multiple_choice',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.radio_button_checked, size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Option Question (Multiple Choice)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'fill_in',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit, size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Fill In Question',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _questionType = value;
                          // Clear fields when switching types
                          if (value == 'fill_in') {
                            for (var controller in _optionControllers) {
                              controller.text = '';
                            }
                            _correctOptionIndex = 0;
                          } else {
                            _fillInAnswerController.text = '';
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Question Text
                  TextFormField(
                    controller: _questionTextController,
                    decoration: const InputDecoration(
                      labelText: 'Question',
                      border: OutlineInputBorder(),
                      helperText: 'Required',
                    ),
                    maxLines: 3,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Please enter a question' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // Conditional UI based on question type
                  if (_questionType == 'multiple_choice') ...[
                    // Options Section
                    const Text(
                      'Options',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(4, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _optionControllers[index],
                                decoration: InputDecoration(
                                  labelText: 'Option ${index + 1}',
                                  border: const OutlineInputBorder(),
                                  helperText: 'Required',
                                  suffixIcon: _correctOptionIndex == index
                                      ? const Icon(Icons.check_circle, color: Colors.green)
                                      : null,
                                ),
                                validator: _questionType == 'multiple_choice'
                                    ? (value) => value?.isEmpty ?? true ? 'Please enter an option' : null
                                    : null,
                              ),
                            ),
                            Radio<int>(
                              value: index,
                              groupValue: _correctOptionIndex,
                              onChanged: (value) {
                                setState(() {
                                  _correctOptionIndex = value!;
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ] else if (_questionType == 'fill_in') ...[
                    // Fill In Answer Section
                    const Text(
                      'Correct Answer',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _fillInAnswerController,
                      decoration: const InputDecoration(
                        labelText: 'Correct Answer',
                        border: OutlineInputBorder(),
                        helperText: 'Enter the expected answer for this fill-in question',
                      ),
                      maxLines: 2,
                      validator: _questionType == 'fill_in'
                          ? (value) => value?.isEmpty ?? true ? 'Please enter the correct answer' : null
                          : null,
                    ),
                  ],
                  const SizedBox(height: 16),
                  
                  // Difficulty Dropdown
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
                        setState(() {
                          _selectedDifficulty = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Points Text Field
                  TextFormField(
                    controller: _pointsController,
                    decoration: const InputDecoration(
                      labelText: 'Points',
                      border: OutlineInputBorder(),
                      helperText: 'Default: 1',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return null; // Optional field
                      }
                      final points = int.tryParse(value);
                      if (points == null || points < 1) {
                        return 'Please enter a valid number (>= 1)';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      final points = int.tryParse(value);
                      if (points != null && points >= 1) {
                        setState(() {
                          _points = points;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Save Button
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveQuestion,
                    icon: const Icon(Icons.save),
                    label: Text(_isLoading ? 'Saving...' : 'Save Question'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _questionTextController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    _topicController.dispose();
    _pointsController.dispose();
    _fillInAnswerController.dispose();
    super.dispose();
  }
}

