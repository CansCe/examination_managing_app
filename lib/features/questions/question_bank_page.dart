import 'package:flutter/material.dart';
import '../../models/question.dart';
import '../../services/mongodb_service.dart';
import '../../utils/dialog_helper.dart';
import 'question_edit_page.dart';

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
      DialogHelper.showErrorDialog(
        context: context,
        title: 'Error Loading Questions',
        message: 'An error occurred while loading questions: $e',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToQuestionEdit({Question? question}) async {
    // Only teachers can navigate to question edit (teacherId is required)
    if (widget.teacherId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Denied: Only teachers can create or edit questions.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionEditPage(
          questionId: question?.id.toHexString(),
          teacherId: widget.teacherId,
          examId: question?.examId,
        ),
      ),
    );

    // Reload questions if the result indicates success
    if (result == true && mounted) {
      _loadQuestions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Question Bank'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToQuestionEdit(),
            tooltip: 'Add New Question',
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
                              if (value == 'edit') {
                                _navigateToQuestionEdit(question: question);
                              } else if (value == 'delete') {
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