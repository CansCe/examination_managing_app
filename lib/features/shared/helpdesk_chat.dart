import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../services/index.dart';
import '../../utils/logger.dart';

const _uuid = Uuid();

class HelpdeskChat extends StatefulWidget {
  final String? studentId;
  final String? targetUserId; // Admin or teacher ID
  final String? targetUserRole; // 'admin' or 'teacher'
  final String? userRole; // Current user role
  
  const HelpdeskChat({
    Key? key, 
    this.studentId,
    this.targetUserId,
    this.targetUserRole,
    this.userRole,
  }) : super(key: key);

  @override
  State<HelpdeskChat> createState() => _HelpdeskChatState();
}

class _HelpdeskChatState extends State<HelpdeskChat> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  ChatSocketService? _chatService;
  bool _showInfoBanner = false;
  String? _resolvedTargetId;
  String _resolvedTargetRole = 'admin';

  @override
  void initState() {
    super.initState();
    _resolveAndConnect();
  }

  Future<void> _resolveAndConnect() async {
    if (widget.studentId == null) {
      setState(() { _isLoading = false; });
      return;
    }

    setState(() { _isLoading = true; });

    try {
      _resolvedTargetId = widget.targetUserId;
      _resolvedTargetRole = widget.targetUserRole ?? 'admin';

      if (_resolvedTargetId == null) {
        final api = ApiService();
        _resolvedTargetId = await api.getDefaultAdminId();
        api.close();
      }

      if (_resolvedTargetId == null) {
        setState(() { _isLoading = false; _showInfoBanner = true; });
        return;
      }

      _chatService = ChatSocketService();
      try {
        await _chatService!.connect(
          userId: widget.studentId!,
          userRole: widget.userRole ?? 'student',
          targetUserId: _resolvedTargetId!,
          targetUserRole: _resolvedTargetRole,
        );

        // Check if connection succeeded
        if (!_chatService!.isConnected) {
          if (!mounted) return;
          setState(() { 
            _isLoading = false;
            _showInfoBanner = true;
          });
          return;
        }
      } catch (e) {
        Logger.error('Error connecting to chat', e, null, 'HelpdeskChat');
        if (!mounted) return;
        setState(() { 
          _isLoading = false;
          _showInfoBanner = true;
        });
        return;
      }

      _chatService!.historyStream.listen((messages) {
        if (!mounted) return;
        setState(() {
          _messages..clear()..addAll(messages);
          _isLoading = false;
        });
        _scrollToBottom();
        if (_messages.isEmpty || DateTime.now().difference(_messages.last.timestamp).inMinutes > 30) {
          setState(() { _showInfoBanner = true; });
        }
      });

      _chatService!.messageStream.listen((message) {
        if (!mounted) return;
        setState(() {
          // Only add if not already in the list (check by ID or by content+timestamp for optimistic messages)
          final exists = _messages.any((m) => 
            m.id == message.id ||
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
      });
      
      // Set loading to false after connection attempt
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    } catch (e) {
      Logger.error('Error in _resolveAndConnect', e, null, 'HelpdeskChat');
      if (!mounted) return;
      setState(() { 
        _isLoading = false;
        _showInfoBanner = true;
      });
    }
  }

  Future<void> _sendMessage() async {
    if (widget.studentId == null || _resolvedTargetId == null) return;
    
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    
    if (_chatService == null || !_chatService!.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not connected to chat server. Please wait for connection.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    _controller.clear();
    
    // Optimistically add message to UI immediately (like Messenger)
    final tempMessage = ChatMessage(
      id: _uuid.v4(), // Generate UUID for temporary message
      fromUserId: widget.studentId!,
      fromUserRole: widget.userRole ?? 'student',
      toUserId: _resolvedTargetId!,
      toUserRole: _resolvedTargetRole,
      message: text,
      timestamp: DateTime.now(),
    );
    
    setState(() {
      _messages.add(tempMessage);
      // Keep sorted by timestamp
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });
    _scrollToBottom();
    
    try {
      // Send via socket - the server will broadcast it back, and we'll update the temp message with real ID
      _chatService!.sendMessage(
        message: text,
        fromUserId: widget.studentId!,
        fromUserRole: widget.userRole ?? 'student',
        toUserId: _resolvedTargetId!,
        toUserRole: _resolvedTargetRole,
      );
      // Don't remove the message - let the WebSocket update it with the real server message
      // The duplicate check in messageStream listener will handle it
      if (_showInfoBanner) {
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) setState(() { _showInfoBanner = false; });
        });
      }
    } catch (e) {
      // Only remove if send actually failed
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => 
            m.message == text && 
            m.fromUserId == widget.studentId! && 
            m.timestamp.difference(tempMessage.timestamp).inSeconds.abs() < 2
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
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

  /// Refresh messages manually (pull to refresh)
  Future<void> _refreshMessages() async {
    if (_chatService == null || widget.studentId == null || _resolvedTargetId == null) return;
    
    try {
      // If disconnected, try to reconnect
      if (!_chatService!.isConnected) {
        Logger.info('Not connected, attempting to reconnect...', 'HelpdeskChat');
        await _chatService!.connect(
          userId: widget.studentId!,
          userRole: widget.userRole ?? 'student',
          targetUserId: _resolvedTargetId!,
          targetUserRole: _resolvedTargetRole,
        );
      }
      
      // Manually reload history
      await _chatService!.reloadHistory();
      
      // Also directly fetch to ensure we have latest messages
      final api = ApiService();
      final messages = await api.getChatMessages(
        userId: widget.studentId!,
        targetUserId: _resolvedTargetId!,
      );
      api.close();
      
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(
            messages.map((m) => ChatMessage.fromMap(m)).toList()
          );
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        });
        _scrollToBottom();
      }
    } catch (e) {
      Logger.error('Error refreshing messages', e, null, 'HelpdeskChat');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh messages: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _chatService?.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 350,
        height: 500,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                color: Colors.blue,
              ),
              child: Row(
                children: [
                  const Icon(Icons.support_agent, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text(
                    'Helpdesk Chat',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  if (_chatService != null && _chatService!.isConnected)
                    const Tooltip(
                      message: 'Connected',
                      child: Icon(Icons.circle, color: Colors.green, size: 12),
                    )
                  else
                    const Tooltip(
                      message: 'Disconnected - Check server connection',
                      child: Icon(Icons.circle, color: Colors.red, size: 12),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Exit',
                    onPressed: () {
                      Navigator.of(context).maybePop();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Stack(
                      children: [
                        // Connection status indicator
                        if (_chatService != null)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              color: _chatService!.isConnected ? Colors.green[50] : Colors.orange[50],
                              child: Row(
                                children: [
                                  Icon(
                                    _chatService!.isConnected ? Icons.wifi : Icons.wifi_off,
                                    size: 16,
                                    color: _chatService!.isConnected ? Colors.green : Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _chatService!.isConnected ? 'Connected' : 'Disconnected - Reconnecting...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _chatService!.isConnected ? Colors.green[700] : Colors.orange[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_messages.isEmpty)
                          const Center(
                            child: Text(
                              'No messages yet.\nStart a conversation!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        else
                          RefreshIndicator(
                            onRefresh: _refreshMessages,
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 16),
                              itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              
                              // Determine if message is from current user (student/teacher)
                              // Check by role first (most reliable), then by ID
                              final currentUserRole = widget.userRole ?? 'student';
                              final isFromCurrentUser = msg.fromUserRole == currentUserRole;
                              
                              // Also check ID match (handle encoding differences)
                              final msgFromUserId = msg.fromUserId.toString();
                              final currentUserId = widget.studentId.toString();
                              
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
                              final normalizedCurrentId = normalizeId(currentUserId);
                              final isIdMatch = normalizedMsgId == normalizedCurrentId;
                              
                              // Message is from current user if role matches OR if IDs match
                              final isUser = isFromCurrentUser || isIdMatch;
                              
                              return Align(
                                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isUser ? Colors.blue[100] : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                        if (_chatService != null && !_chatService!.isConnected)
                          Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              margin: const EdgeInsets.all(12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red[300]!),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Disconnected - Chat service not available',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Make sure backend-chat service is running on port 3001',
                                    style: TextStyle(

                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      setState(() {
                                        _isLoading = true;
                                      });
                                      await _resolveAndConnect();
                                    },
                                    icon: const Icon(Icons.refresh, size: 16),
                                    label: const Text('Retry Connection'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[700],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_showInfoBanner && (_chatService == null || _chatService!.isConnected))
                          Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              margin: const EdgeInsets.all(12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: const Text(
                                'Your info has been passed  please wait till an admin contact you',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
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
    );
  }
}
