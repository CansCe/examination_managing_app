import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../services/index.dart';
import '../../models/index.dart';

const _uuid = Uuid();

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
  Map<String, String> _lastMessages = {}; // studentId -> last message preview
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
      // Get all students that have chat history (with last message info)
      final api = ApiService();
      final conversationsData = await api.getChatConversations();
      api.close();
      
      // Extract student IDs and last messages
      final studentIdsWithChat = <String>[];
      final lastMessagesMap = <String, String>{};
      
      for (var conv in conversationsData) {
        final studentId = (conv['studentId'] ?? (conv['student']?['id']))?.toString();
        if (studentId != null) {
          studentIdsWithChat.add(studentId);
          // Get last message preview
          if (conv['lastMessage'] != null) {
            final lastMsg = conv['lastMessage'] as Map<String, dynamic>;
            final messageText = lastMsg['message']?.toString() ?? '';
            if (messageText.isNotEmpty) {
              // Truncate to 50 chars for preview
              final preview = messageText.length > 50 
                  ? '${messageText.substring(0, 50)}...' 
                  : messageText;
              lastMessagesMap[studentId] = preview;
            }
          }
        }
      }
      
      print('📋 Students with chat history (raw): ${studentIdsWithChat.length}');
      for (var id in studentIdsWithChat) {
        print('  - $id (format: ${id.contains('-') ? 'UUID' : 'ObjectId'})');
      }
      
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

      // Helper to decode UUID-encoded IDs to ObjectId format
      // UUID format: 454d4150-6907-fcdc-6666-2850167405fd
      // Where 454d4150 is the prefix "MAPI" in hex (4 bytes)
      // The ObjectId is in the remaining parts: 6907fcdc66662850167405fd (24 hex chars)
      String decodeChatUserId(String id) {
        if (id.isEmpty) return id;
        // If it's not a UUID, return as-is
        if (!id.contains('-') || id.length != 36) {
          return id;
        }
        
        try {
          final uuidParts = id.split('-');
          if (uuidParts.length == 5) {
            // Check if it starts with our prefix (454d4150 = "MAPI")
            if (uuidParts[0].toLowerCase() == '454d4150') {
              // Extract the ObjectId from parts 1-4 (skip the prefix)
              // Parts 1-4: 6907-fcdc-6666-2850167405fd
              // Join them: 6907fcdc66662850167405fd (should be 24 chars)
              final hexString = uuidParts.sublist(1).join('');
              if (hexString.length == 24) {
                return hexString.toLowerCase();
              } else {
                print('⚠ Warning: Decoded hex string length is ${hexString.length}, expected 24');
              }
            }
          }
          return id; // Return original if decoding fails
        } catch (e) {
          print('Error decoding chat user ID: $e');
          return id;
        }
      }

      // Decode all student IDs from chat history
      final decodedStudentIds = studentIdsWithChat.map((id) {
        final decoded = decodeChatUserId(id);
        print('  Decoded: $id -> $decoded');
        return decoded;
      }).toSet().toList();

      // Fetch all students with pagination and filter to only those with chat history
      // Backend has max limit of 100, so we'll fetch in batches
      List<Student> allStudents = [];
      int page = 0;
      const int limit = 100; // Max allowed by backend
      bool hasMore = true;
      
      while (hasMore) {
        final batch = await AtlasService.findStudents(page: page, limit: limit);
        if (batch.isEmpty) {
          hasMore = false;
        } else {
          allStudents.addAll(batch);
          // If we got fewer than the limit, we've reached the end
          if (batch.length < limit) {
            hasMore = false;
          } else {
            page++;
          }
        }
      }
      
      print('📋 Fetched ${allStudents.length} total students from database');
      
      final studentsWithChat = allStudents.where((student) {
        final matches = decodedStudentIds.contains(student.id) || studentIdsWithChat.contains(student.id);
        if (matches) {
          print('  ✓ Matched student: ${student.id} (${student.fullName})');
        }
        return matches;
      }).toList();
      
      print('📋 Found ${studentsWithChat.length} students with chat history');

      // Sort by last message time (most recent first)
      // For now, we'll keep the order as returned, but prioritize those with unread messages
      
      // Decode last message student IDs to match with student list
      final decodedLastMessages = <String, String>{};
      for (var entry in lastMessagesMap.entries) {
        final decodedId = decodeChatUserId(entry.key);
        decodedLastMessages[decodedId] = entry.value;
        // Also keep original in case it's already decoded
        if (decodedId != entry.key) {
          decodedLastMessages[entry.key] = entry.value;
        }
      }
      
      if (mounted) {
        setState(() {
          _allStudents = studentsWithChat;
          _filteredStudents = studentsWithChat;
          _lastMessages = decodedLastMessages;
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
      
      print('📊 Updating unread message counts. Found ${unreadMessages.length} unread messages');
      print('📋 Students in list: ${_allStudents.length}');
      
      // Helper to decode UUID-encoded IDs to ObjectId format (same as in _loadStudents)
      String decodeChatUserId(String id) {
        if (id.isEmpty) return id;
        if (!id.contains('-') || id.length != 36) {
          return id;
        }
        try {
          final uuidParts = id.split('-');
          if (uuidParts.length == 5 && uuidParts[0].toLowerCase() == '454d4150') {
            final hexString = uuidParts.sublist(1).join('');
            if (hexString.length == 24) {
              return hexString.toLowerCase();
            }
          }
          return id;
        } catch (e) {
          return id;
        }
      }
      
      for (var msg in unreadMessages) {
        // Get student ID from the message (fromUserId if student sent it)
        String messageStudentId = msg.fromUserRole == 'student' ? msg.fromUserId : msg.toUserId;
        print('  📨 Message from student ID: $messageStudentId (format: ${messageStudentId.contains('-') ? 'UUID' : 'ObjectId'})');
        
        // Decode if it's UUID-encoded
        final decodedStudentId = decodeChatUserId(messageStudentId);
        if (decodedStudentId != messageStudentId) {
          print('    Decoded to: $decodedStudentId');
        }
        
        // Try to find matching student in the list using both encoded and decoded IDs
        Student? matchingStudent;
        
        // First, try direct match with decoded ID
        try {
          matchingStudent = _allStudents.firstWhere(
            (s) => s.id == decodedStudentId,
          );
          print('    ✓ Match found with decoded ID: ${matchingStudent.id}');
        } catch (e) {
          // Try with original ID (in case it's already ObjectId)
          try {
            matchingStudent = _allStudents.firstWhere(
              (s) => s.id == messageStudentId,
            );
            print('    ✓ Match found with original ID: ${matchingStudent.id}');
          } catch (e2) {
            print('    ⚠ No match found - student might not be in list yet');
          }
        }
        
        // Use the matching student ID if found, otherwise use the decoded ID
        final studentId = matchingStudent?.id ?? decodedStudentId;
        counts[studentId] = (counts[studentId] ?? 0) + 1;
        print('    📊 Count for $studentId: ${counts[studentId]}');
      }
      
      // Debug: Print final counts
      print('📊 Final unread counts:');
      counts.forEach((id, count) {
        print('  - $id: $count');
      });
      
      if (mounted) {
        setState(() {
          _unreadMessageCounts = counts;
        });
      }
    } catch (e) {
      print('Error updating unread message counts: $e');
      print('Stack trace: ${StackTrace.current}');
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
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            student.rollNumber,
                                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                          ),
                                          if (_lastMessages.containsKey(student.id))
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4.0),
                                              child: Text(
                                                _lastMessages[student.id]!,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: unreadCount > 0 ? Colors.blue[700] : Colors.grey[600],
                                                  fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                      ),
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
  final List<ChatMessage> _messages = [];
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

  Future<void> _initializeChat() async {
    _chatService = ChatSocketService();
    
    try {
      // Connect to chat
      await _chatService!.connect(
        userId: widget.adminId,
        userRole: 'admin',
        targetUserId: widget.student.id,
        targetUserRole: 'student',
      );

      // Check if connection succeeded
      if (!_chatService!.isConnected) {
        if (mounted) {
          setState(() {
            _isLoadingMessages = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to connect to chat service. Please check server connection.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }
    } catch (e) {
      print('Error connecting to chat: $e');
      if (mounted) {
        setState(() {
          _isLoadingMessages = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect to chat service: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    // Listen for chat history
    _chatService!.historyStream.listen((messages) {
      if (mounted) {
        print('📨 Received ${messages.length} messages in history stream');
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
        print('📨 Received new message via Socket.io: ${message.message} from ${message.fromUserRole}');
        setState(() {
          // Check if message already exists by ID (most reliable)
          final existsById = message.id.isNotEmpty && _messages.any((m) => m.id == message.id);
          
          // Also check by content+timestamp+fromUserId (for messages without ID or duplicate IDs)
          final existsByContent = _messages.any((m) => 
            m.message == message.message && 
            m.fromUserId == message.fromUserId && 
            m.fromUserRole == message.fromUserRole &&
            m.timestamp.difference(message.timestamp).inSeconds.abs() < 3
          );
          
          if (!existsById && !existsByContent) {
            print('  ✓ Adding new message to list');
            _messages.add(message);
            // Sort by timestamp to maintain order
            _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          } else {
            print('  ⚠ Message already exists, skipping (existsById: $existsById, existsByContent: $existsByContent)');
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
    // Disconnect gracefully before disposing
    _chatService?.disconnect().then((_) {
      _chatService?.dispose();
    }).catchError((e) {
      print('Error disposing chat service: $e');
      _chatService?.dispose();
    });
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
      id: _uuid.v4(), // Generate UUID for temporary message
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
                      
                      // Determine if message is from admin (right side) or from student/teacher (left side)
                      // Check by role first (most reliable), then by ID match
                      final isFromAdmin = msg.fromUserRole == 'admin';
                      
                      // Also check ID match (normalize both to handle UUID/ObjectId differences)
                      final msgFromUserId = msg.fromUserId;
                      final adminId = widget.adminId;
                      
                      // Helper to normalize IDs for comparison
                      String normalizeId(String id) {
                        if (id.isEmpty) return id;
                        // If it's a UUID, try to decode it
                        if (id.contains('-') && id.length == 36) {
                          try {
                            final uuidParts = id.split('-');
                            if (uuidParts.length == 5 && uuidParts[0].toLowerCase() == '454d4150') {
                              final hexString = uuidParts.sublist(1).join('');
                              if (hexString.length == 24) {
                                return hexString.toLowerCase();
                              }
                            }
                          } catch (e) {
                            // If decoding fails, return original
                          }
                        }
                        return id.toLowerCase();
                      }
                      
                      final normalizedMsgId = normalizeId(msgFromUserId);
                      final normalizedAdminId = normalizeId(adminId);
                      final isIdMatch = normalizedMsgId == normalizedAdminId;
                      
                      // Message is from admin if role is admin OR if IDs match
                      final isMe = isFromAdmin || (isIdMatch && msg.fromUserRole == 'admin');
                      
                      // Debug log for alignment issues
                      if (index == 0 || index == _messages.length - 1) {
                        print('📨 Message alignment check:');
                        print('  Message fromUserId: $msgFromUserId (normalized: $normalizedMsgId)');
                        print('  Admin ID: $adminId (normalized: $normalizedAdminId)');
                        print('  Message role: ${msg.fromUserRole}');
                        print('  isFromAdmin: $isFromAdmin, isIdMatch: $isIdMatch');
                        print('  Final isMe: $isMe (will align ${isMe ? "RIGHT" : "LEFT"})');
                      }
                      
                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blue[100] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
