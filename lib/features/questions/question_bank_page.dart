import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' hide State, Center;
import '../../models/question.dart';
import '../../services/mongodb_service.dart';

class QuestionBankPage extends StatefulWidget {
  final String teacherId;

  const QuestionBankPage({
    Key? key,
    required this.teacherId,
  }) : super(key: key);

  @override
  State<QuestionBankPage> createState() => _QuestionBankPageState();
}

class _QuestionBankPageState extends State<QuestionBankPage> {
  List<Question> _questions = [];
  String _selectedSubject = '';
  String _selectedDifficulty = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      final questions = await MongoDBService.getQuestionsBySubject(_selectedSubject);
      setState(() {
        _questions = questions;
        if (_selectedDifficulty.isNotEmpty) {
          _questions = _questions.where((q) => q.difficulty == _selectedDifficulty).toList();
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading questions: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddQuestionDialog() async {
    final formKey = GlobalKey<FormState>();
    final questionController = TextEditingController();
    final optionsControllers = List.generate(4, (_) => TextEditingController());
    String selectedSubject = _selectedSubject;
    String selectedDifficulty = 'medium';
    String selectedTopic = '';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Question'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedSubject,
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
                      selectedSubject = value;
                    }
                  },
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Please select a subject' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: TextEditingController(text: selectedTopic),
                  decoration: const InputDecoration(
                    labelText: 'Topic',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => selectedTopic = value,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Please enter a topic' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: questionController,
                  decoration: const InputDecoration(
                    labelText: 'Question',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Please enter a question' : null,
                ),
                const SizedBox(height: 16),
                ...List.generate(4, (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: TextFormField(
                        controller: optionsControllers[index],
                        decoration: InputDecoration(
                          labelText: 'Option ${index + 1}',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Please enter an option' : null,
                      ),
                    )),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedDifficulty,
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
                      selectedDifficulty = value;
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Correct Option',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(4, (index) => DropdownMenuItem(
                        value: index,
                        child: Text('Option ${index + 1}'),
                      )),
                  onChanged: (value) {
                    if (value != null) {
                      // Store the correct option index
                      selectedDifficulty = value.toString();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final question = Question(
                  id: ObjectId(),
                  text: questionController.text,
                  questionText: questionController.text,
                  type: 'multiple_choice',
                  options: optionsControllers.map((c) => c.text).toList(),
                  correctOptionIndex: int.parse(selectedDifficulty),
                  subject: selectedSubject,
                  topic: selectedTopic,
                  difficulty: selectedDifficulty,
                  points: 1,
                  examId: ObjectId(),
                  createdBy: ObjectId.fromHexString(widget.teacherId),
                  correctAnswer: optionsControllers[int.parse(selectedDifficulty)].text,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                final success = await MongoDBService.createQuestion(question);
                if (success && mounted) {
                  Navigator.pop(context);
                  _loadQuestions();
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Question Bank'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddQuestionDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSubject,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('All Subjects')),
                      ...['Mathematics', 'Physics', 'Chemistry', 'Biology']
                          .map((subject) => DropdownMenuItem(
                                value: subject,
                                child: Text(subject),
                              ))
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedSubject = value ?? '';
                        _loadQuestions();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedDifficulty,
                    decoration: const InputDecoration(
                      labelText: 'Difficulty',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('All Difficulties')),
                      ...['easy', 'medium', 'hard']
                          .map((difficulty) => DropdownMenuItem(
                                value: difficulty,
                                child: Text(difficulty.toUpperCase()),
                              ))
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedDifficulty = value ?? '';
                        _loadQuestions();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _questions.length,
                    itemBuilder: (context, index) {
                      final question = _questions[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          title: Text(question.questionText),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Subject: ${question.subject}'),
                              Text('Topic: ${question.topic}'),
                              Text('Difficulty: ${question.difficulty.toUpperCase()}'),
                              const SizedBox(height: 8),
                              ...question.options.asMap().entries.map(
                                    (entry) => Text(
                                      '${entry.key + 1}. ${entry.value}',
                                      style: TextStyle(
                                        color: entry.key == question.correctOptionIndex
                                            ? Colors.green
                                            : null,
                                        fontWeight: entry.key == question.correctOptionIndex
                                            ? FontWeight.bold
                                            : null,
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                            onSelected: (value) async {
                              if (value == 'delete') {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Question'),
                                    content: const Text(
                                      'Are you sure you want to delete this question?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmed == true) {
                                  final success = await MongoDBService.deleteQuestion(
                                    question.id,
                                  );
                                  if (success && mounted) {
                                    _loadQuestions();
                                  }
                                }
                              }
                              // TODO: Implement edit functionality
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
} 