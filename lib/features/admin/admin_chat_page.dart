import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' hide State,Center;
import '../../services/index.dart';
import '../../models/index.dart';

class AdminChatPage extends StatefulWidget {
  final String adminId;
  
  const AdminChatPage({Key? key, required this.adminId}) : super(key: key);

  @override
  State<AdminChatPage> createState() => _AdminChatPageState();
}

class _AdminChatPageState extends State<AdminChatPage> {
  List<Student> _allStudents = []; // All students with chat history
  List<Student> _filteredStudents = []; // Filtered by search
  bool _isLoading = true;
  Map<String, int> _unreadMessageCounts = {}; // studentId -> count
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterStudents);
    _loadStudents();
    _startPollingUnreadMessages();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _filteredStudents = _allStudents;
      });
    } else {
      setState(() {
        _filteredStudents = _allStudents.where((student) {
          final nameMatch = student.fullName.toLowerCase().contains(query);
          final idMatch = student.rollNumber.toLowerCase().contains(query) ||
                         student.id.toLowerCase().contains(query);
          return nameMatch || idMatch;
        }).toList();
      });
    }
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all students that have chat history
      final studentIdsWithChat = await ChatService.getStudentsWithChatHistory();
      
      if (studentIdsWithChat.isEmpty) {
        if (mounted) {
          setState(() {
            _allStudents = [];
            _filteredStudents = [];
            _isLoading = false;
          });
        }
        await _updateUnreadMessageCounts();
        return;
      }

      // Fetch all students and filter to only those with chat history
      final allStudents = await AtlasService.findStudents(limit: 1000);
      final studentsWithChat = allStudents.where((student) {
        return studentIdsWithChat.contains(student.id);
      }).toList();

      // Sort by last message time (most recent first)
      // For now, we'll keep the order as returned, but prioritize those with unread messages
      
      if (mounted) {
        setState(() {
          _allStudents = studentsWithChat;
          _filteredStudents = studentsWithChat;
        });
      }
      await _updateUnreadMessageCounts();
      
      // Sort by unread count (students with unread messages first)
      if (mounted) {
        setState(() {
          _allStudents.sort((a, b) {
            final aUnread = _unreadMessageCounts[a.id] ?? 0;
            final bUnread = _unreadMessageCounts[b.id] ?? 0;
            if (aUnread != bUnread) {
              return bUnread.compareTo(aUnread); // Higher unread count first
            }
            return a.fullName.compareTo(b.fullName); // Then alphabetically
          });
          _filterStudents(); // Re-apply filter
        });
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading students: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateUnreadMessageCounts() async {
    try {
      final unreadMessages = await ChatService.getUnreadMessages();
      final Map<String, int> counts = {};
      for (var msg in unreadMessages) {
        // Get student ID from the message (fromUserId if student sent it)
        final studentId = msg.fromUserRole == 'student' ? msg.fromUserId : msg.toUserId;
        counts[studentId] = (counts[studentId] ?? 0) + 1;
      }
      if (mounted) {
        setState(() {
          _unreadMessageCounts = counts;
        });
      }
    } catch (e) {
      print('Error updating unread message counts: $e');
    }
  }

  void _startPollingUnreadMessages() {
    Future.delayed(const Duration(seconds: 5), () async {
      if (!mounted) return;
      await _updateUnreadMessageCounts();
      _startPollingUnreadMessages(); // Schedule next poll
    });
  }

  void _navigateToChat(Student student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminChatConversationPage(
          adminId: widget.adminId,
          student: student,
        ),
      ),
    ).then((_) {
      // Refresh student list when returning from chat
      _loadStudents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Support Chat'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back to Home',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStudents,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, child) {
                return TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by student name or ID...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: value.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                );
              },
            ),
          ),
          // Student List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      if (_filteredStudents.isEmpty && _searchController.text.length == 24 && RegExp(r'^[0-9a-fA-F]{24}').hasMatch(_searchController.text))
                        Card(
                          color: Colors.blue[50],
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.person_add),
                                title: const Text('Start chat with Student by ID'),
                                subtitle: Text(_searchController.text),
                                onTap: () {
                                  final dummyStudent = Student(
                                    id: _searchController.text,
                                    rollNumber: _searchController.text,
                                    className: '',
                                    email: '', firstName: 'unknown', lastName: 'student', phoneNumber: '', address: '', assignedExams: [],
                                  );
                                  _navigateToChat(dummyStudent);
                                },
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.school),
                                title: const Text('Start chat with Teacher by ID'),
                                subtitle: Text(_searchController.text),
                                onTap: () {
                                  // Reuse student path but pass ID into conversation page using minimal student
                                  final dummyStudent = Student(
                                    id: _searchController.text,
                                    rollNumber: _searchController.text,
                                    className: '',
                                    email: '', firstName: 'Unknown', lastName: 'Teacher', phoneNumber: '', address: '', assignedExams: [],
                                  );
                                  _navigateToChat(dummyStudent);
                                },
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: _filteredStudents.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchController.text.isEmpty
                                          ? 'No chat conversations yet'
                                          : 'No students found',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                itemCount: _filteredStudents.length,
                                itemBuilder: (context, index) {
                                  final student = _filteredStudents[index];
                                  final unreadCount = _unreadMessageCounts[student.id] ?? 0;
                                  
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 4,
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        child: Text(
                                          student.fullName.isNotEmpty
                                              ? student.fullName[0].toUpperCase()
                                              : '?',
                                        ),
                                      ),
                                      title: Text(
                                        student.fullName,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(student.rollNumber),
                                      trailing: unreadCount > 0
                                          ? Container(
                                              width: 32,
                                              height: 32,
                                              alignment: Alignment.center,
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                unreadCount > 99 ? '99+' : '$unreadCount',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            )
                                          : const Icon(Icons.chevron_right, color: Colors.grey),
                                      onTap: () => _navigateToChat(student),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class AdminChatConversationPage extends StatefulWidget {
  final String adminId;
  final Student student;

  const AdminChatConversationPage({
    Key? key,
    required this.adminId,
    required this.student,
  }) : super(key: key);

  @override
  State<AdminChatConversationPage> createState() =>
      _AdminChatConversationPageState();
}

class _AdminChatConversationPageState
    extends State<AdminChatConversationPage> {
  List<ChatMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMessages = true;
  ChatSocketService? _chatService;
  Map<String, dynamic>? _conversationMetadata;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      final api = ApiService();
      final meta = await api.getConversationMetadata(
        userId: widget.adminId,
        targetUserId: widget.student.id,
      );
      api.close();
      if (mounted) {
        setState(() {
          _conversationMetadata = meta;
        });
      }
    } catch (e) {
      print('Error loading metadata: $e');
    }
  }

  Future<void> _showMetadataDialog() async {
    final topicController = TextEditingController(text: _conversationMetadata?['topic'] ?? '');
    String? priority = _conversationMetadata?['priority'] ?? 'normal';
    final assignedAdminController = TextEditingController(text: _conversationMetadata?['assignedAdmin']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Conversation Metadata'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: topicController,
                decoration: const InputDecoration(labelText: 'Topic'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: ['low', 'normal', 'high', 'urgent']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase())))
                    .toList(),
                onChanged: (v) {
                  setDialogState(() => priority = v);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: assignedAdminController,
                decoration: const InputDecoration(labelText: 'Assigned Admin ID (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final api = ApiService();
                  await api.createOrUpdateConversation(
                    userId: widget.adminId,
                    targetUserId: widget.student.id,
                    topic: topicController.text.trim().isEmpty ? null : topicController.text.trim(),
                    priority: priority,
                    assignedAdmin: assignedAdminController.text.trim().isEmpty ? null : assignedAdminController.text.trim(),
                  );
                  api.close();
                  if (mounted) {
                    Navigator.pop(ctx);
                    await _loadMetadata();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Metadata updated')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _initializeChat() {
    _chatService = ChatSocketService();
    
    // Connect to chat
    _chatService!.connect(
      userId: widget.adminId,
      userRole: 'admin',
      targetUserId: widget.student.id,
      targetUserRole: 'student',
    );

    // Listen for chat history
    _chatService!.historyStream.listen((messages) {
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(messages);
          _isLoadingMessages = false;
        });
        _scrollToBottom();
        // Mark messages as read
        _chatService?.markAsRead(widget.adminId, widget.student.id);
      }
    });

    // Listen for new messages
    _chatService!.messageStream.listen((message) {
      if (mounted) {
        setState(() {
          // Only add if not already in the list (check by ID or by content+timestamp for optimistic messages)
          final exists = _messages.any((m) => 
            m.id.toHexString() == message.id.toHexString() ||
            (m.message == message.message && 
             m.fromUserId == message.fromUserId && 
             (m.timestamp.difference(message.timestamp).inSeconds.abs() < 2))
          );
          if (!exists) {
            _messages.add(message);
            // Sort by timestamp to maintain order
            _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          }
        });
        _scrollToBottom();
        // Mark as read if from student
        if (message.fromUserRole == 'student') {
          _chatService?.markAsRead(widget.adminId, widget.student.id);
        }
      }
    });
  }

  @override
  void dispose() {
    _chatService?.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _chatService == null) return;

    final text = _messageController.text.trim();
    _messageController.clear();

    // Optimistically add message to UI immediately (like Messenger)
    final tempMessage = ChatMessage(
      id: ObjectId(),
      fromUserId: widget.adminId,
      fromUserRole: 'admin',
      toUserId: widget.student.id,
      toUserRole: 'student',
      message: text,
      timestamp: DateTime.now(),
      isRead: true, // Admin messages are considered read by admin
    );

    setState(() {
      _messages.add(tempMessage);
      // Keep sorted by timestamp
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });
    _scrollToBottom();

    try {
      // Send via WebSocket - the server will broadcast it back, and we'll update the temp message with real ID
      _chatService!.sendMessage(
        message: text,
        fromUserId: widget.adminId,
        fromUserRole: 'admin',
        toUserId: widget.student.id,
        toUserRole: 'student',
      );
      // Don't remove the message - let the WebSocket update it with the real server message
      // The duplicate check in messageStream listener will handle it
    } catch (e) {
      if (mounted) {
        // Only remove if send actually failed
        setState(() {
          _messages.removeWhere((m) => 
            m.message == text && 
            m.fromUserId == widget.adminId && 
            m.timestamp.difference(tempMessage.timestamp).inSeconds.abs() < 2
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.student.fullName),
            Text(
              widget.student.rollNumber,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Conversation metadata',
            icon: const Icon(Icons.info_outline),
            onPressed: _showMetadataDialog,
          ),
          if (_conversationMetadata != null && _conversationMetadata!['priority'] != null)
            Chip(
              label: Text(_conversationMetadata!['priority'].toString().toUpperCase()),
              backgroundColor: _conversationMetadata!['priority'] == 'urgent'
                  ? Colors.red[100]
                  : _conversationMetadata!['priority'] == 'high'
                      ? Colors.orange[100]
                      : Colors.blue[100],
            ),
          IconButton(
            tooltip: 'Close conversation',
            icon: const Icon(Icons.delete_forever),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Close conversation'),
                  content: const Text('This will delete all messages in this chat. Continue?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (confirm != true) return;
              try {
                final api = ApiService();
                final ok = await api.closeConversation(userId: widget.adminId, targetUserId: widget.student.id);
                api.close();
                if (!mounted) return;
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Conversation deleted')),
                  );
                  setState(() { _messages.clear(); });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete conversation')),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingMessages
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg.fromUserId == widget.adminId && msg.fromUserRole == 'admin';
                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blue[100] : Colors.grey[200],
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
          Padding(
            padding: const EdgeInsets.all(8.0),
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
    );
  }
}
