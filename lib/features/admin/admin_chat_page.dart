import 'package:flutter/material.dart';
import '../../services/chat_service.dart';
import '../../services/atlas_service.dart';
import '../../models/student.dart';

class AdminChatPage extends StatefulWidget {
  final String adminId;
  
  const AdminChatPage({Key? key, required this.adminId}) : super(key: key);

  @override
  State<AdminChatPage> createState() => _AdminChatPageState();
}

class _AdminChatPageState extends State<AdminChatPage> {
  String? _selectedStudentId;
  List<ChatMessage> _messages = [];
  List<Student> _students = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
    // Refresh messages every 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _refreshMessages();
    });
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all students
      final students = await AtlasService.findStudents();
      
      // Get students with pending messages
      final pendingStudentIds = await ChatService.getStudentsWithPendingMessages();
      
      // Sort students: those with pending messages first
      students.sort((a, b) {
        final aHasPending = pendingStudentIds.contains(a.id.toString());
        final bHasPending = pendingStudentIds.contains(b.id.toString());
        if (aHasPending && !bHasPending) return -1;
        if (!aHasPending && bHasPending) return 1;
        return 0;
      });

      if (mounted) {
        setState(() {
          _students = students;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadConversation(String studentId) async {
    setState(() {
      _selectedStudentId = studentId;
      _isLoading = true;
    });

    try {
      final messages = await ChatService.getConversation(studentId);
      // Mark messages as read
      await ChatService.markAsRead(studentId);
      
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshMessages() async {
    if (_selectedStudentId != null) {
      try {
        final messages = await ChatService.getConversation(_selectedStudentId!);
        if (mounted) {
          setState(() {
            _messages = messages;
          });
          _scrollToBottom();
        }
      } catch (e) {
        // Ignore refresh errors
      }
    }
    
    // Continue refreshing
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _refreshMessages();
    });
  }

  Future<void> _sendMessage() async {
    if (_selectedStudentId == null) return;
    
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      _messageController.clear();
      
      try {
        await ChatService.sendAdminMessage(
          studentId: _selectedStudentId!,
          adminId: widget.adminId,
          message: text,
        );
        await _loadConversation(_selectedStudentId!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send message: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<bool> _hasPendingMessages(String studentId) async {
    try {
      final pendingIds = await ChatService.getStudentsWithPendingMessages();
      return pendingIds.contains(studentId);
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Chat - Student Support'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStudents,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Row(
        children: [
          // Students list sidebar
          Container(
            width: 250,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _students.isEmpty
                    ? const Center(
                        child: Text('No students found'),
                      )
                    : ListView.builder(
                        itemCount: _students.length,
                        itemBuilder: (context, index) {
                          final student = _students[index];
                          final isSelected = _selectedStudentId == student.id.toString();
                          
                          return FutureBuilder<bool>(
                            future: _hasPendingMessages(student.id.toString()),
                            builder: (context, snapshot) {
                              final hasPending = snapshot.data ?? false;
                              
                              return ListTile(
                                title: Text(student.fullName),
                                subtitle: Text(student.email),
                                selected: isSelected,
                                leading: hasPending
                                    ? const Icon(Icons.chat_bubble, color: Colors.orange)
                                    : const Icon(Icons.person),
                                trailing: hasPending
                                    ? Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.orange,
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                    : null,
                                onTap: () => _loadConversation(student.id.toString()),
                              );
                            },
                          );
                        },
                      ),
          ),
          
          // Chat area
          Expanded(
            child: _selectedStudentId == null
                ? const Center(
                    child: Text(
                      'Select a student to start chatting',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                : Column(
                    children: [
                      // Chat header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              _students.firstWhere(
                                (s) => s.id.toString() == _selectedStudentId,
                                orElse: () => _students.first,
                              ).fullName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Messages list
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: _messages.length,
                                itemBuilder: (context, index) {
                                  final msg = _messages[index];
                                  final isAdmin = msg.sender == 'admin';
                                  
                                  return Align(
                                    alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isAdmin ? Colors.blue[100] : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            msg.message,
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      
                      // Message input
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                decoration: InputDecoration(
                                  hintText: 'Type your message...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: _sendMessage,
                              color: Colors.blue,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

