import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' hide State,Center;
import '../../services/chat_service.dart';
import '../../services/atlas_service.dart';
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
        counts[msg.studentId] = (counts[msg.studentId] ?? 0) + 1;
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
                : _filteredStudents.isEmpty
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
  bool _isLoadingMessages = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _startPollingMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoadingMessages = true;
    });
    try {
      final messages = await ChatService.getConversation(widget.student.id);
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoadingMessages = false;
        });
        _scrollToBottom();
        // Mark messages as read after loading
        await ChatService.markAsRead(widget.student.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: $e')),
        );
        setState(() {
          _isLoadingMessages = false;
        });
      }
    }
  }

  void _startPollingMessages() {
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      try {
        final messages = await ChatService.getConversation(widget.student.id);
        if (mounted) {
          setState(() {
            _messages = messages;
          });
          _scrollToBottom();
        }
      } catch (e) {
        // Ignore polling errors
      }
      _startPollingMessages(); // Schedule next poll
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final text = _messageController.text.trim();
    _messageController.clear();

    // Optimistically add message to UI
    final tempMessage = ChatMessage(
      id: ObjectId(),
      studentId: widget.student.id,
      adminId: widget.adminId,
      message: text,
      sender: 'admin',
      timestamp: DateTime.now(),
      isRead: true, // Admin messages are considered read by admin
    );

    setState(() {
      _messages.add(tempMessage);
    });
    _scrollToBottom();

    try {
      await ChatService.sendAdminMessage(
        studentId: widget.student.id,
        adminId: widget.adminId,
        message: text,
      );
      // Reload messages to get actual data from DB and ensure consistency
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.removeLast(); // Remove optimistic message if send failed
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
                      final isMe = msg.sender == 'admin';
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
