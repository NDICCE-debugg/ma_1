import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/screens/call_screen.dart';
import 'package:ma_1/services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String contactName;
  final String? phoneNumber;
  final bool isOnline;
  final String? lastSeen;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.contactName,
    this.phoneNumber,
    this.isOnline = false,
    this.lastSeen,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    ChatService.instance.joinRoom(widget.conversationId);
    ChatService.instance.incomingMessage.addListener(_onMessageReceived);
    ChatService.instance.typingIndicator.addListener(_onTyping);
    _loadMessages();

    // Start background syncing if this is the live Google Chat room
    if (widget.conversationId == 'google-chat-workspace') {
      _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (mounted && !_isSending) {
          _refreshMessagesSilently();
        }
      });
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    ChatService.instance.incomingMessage.removeListener(_onMessageReceived);
    ChatService.instance.typingIndicator.removeListener(_onTyping);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final messages =
        await ChatService.instance.getMessages(widget.conversationId);
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(messages);
      _isLoading = false;
    });
    _scrollToBottom();
  }

  Future<void> _refreshMessagesSilently() async {
    final messages =
        await ChatService.instance.getMessages(widget.conversationId);
    if (!mounted) return;

    // Only update and scroll if the conversation stream has actually changed!
    if (messages.length != _messages.length ||
        (messages.isNotEmpty && _messages.isNotEmpty && messages.last['id'] != _messages.last['id'])) {
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
      });
      _scrollToBottom();
    }
  }

  void _onMessageReceived() {
    final msg = ChatService.instance.incomingMessage.value;
    if (msg != null && msg['conversation_id'] == widget.conversationId) {
      setState(() => _messages.add(msg));
      _scrollToBottom();
    }
  }

  void _onTyping() {
    final data = ChatService.instance.typingIndicator.value;
    if (data != null && data['conversation_id'] == widget.conversationId) {
      setState(() => _isTyping = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isTyping = false);
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      Future.delayed(
        const Duration(milliseconds: 100),
        () {
          if (!_scrollCtrl.hasClients) return;
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        },
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isSending) return;
    final localMessage = {
      'id': 'pending-${DateTime.now().microsecondsSinceEpoch}',
      'conversation_id': widget.conversationId,
      'sender_id': ChatService.instance.currentUserId ?? 'local-technician',
      'sender_name': ChatService.instance.currentUserName ?? 'Technician',
      'message_text': text,
      'message_type': 'text',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'delivery_state': 'sending',
    };

    _msgCtrl.clear();
    setState(() {
      _isSending = true;
      _messages.add(localMessage);
    });
    _scrollToBottom();

    final sentMessage = await ChatService.instance.sendMessage(localMessage);
    if (!mounted) return;
    setState(() {
      final index =
          _messages.indexWhere((msg) => msg['id'] == localMessage['id']);
      if (index != -1) {
        _messages[index] = sentMessage;
      }
      _isSending = false;
    });
    _scrollToBottom();
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_back_outlined,
                  color: AppTheme.primary),
              title:
                  const Text("Camera", style: TextStyle(fontFamily: 'Inter')),
              subtitle: const Text("Attach equipment photo evidence"),
              onTap: () => _sendSystemAttachment(
                  ctx, 'Camera capture queued for this case.'),
            ),
            ListTile(
              leading: const Icon(Icons.add_photo_alternate_outlined,
                  color: AppTheme.primary),
              title:
                  const Text("Gallery", style: TextStyle(fontFamily: 'Inter')),
              subtitle: const Text("Share machine panel or alarm screen"),
              onTap: () => _sendSystemAttachment(
                  ctx, 'Image attachment queued for this case.'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.article_outlined, color: AppTheme.primary),
              title:
                  const Text("Document", style: TextStyle(fontFamily: 'Inter')),
              subtitle: const Text("Attach service report or manual extract"),
              onTap: () => _sendSystemAttachment(
                  ctx, 'Document attachment queued for this case.'),
            ),
          ],
        ),
      ),
    );
  }

  void _sendSystemAttachment(BuildContext sheetContext, String text) {
    Navigator.pop(sheetContext);
    _msgCtrl.text = text;
    _sendMessage();
  }

  void _startCall(bool isVideo) async {
    final startTime = DateTime.now();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          contactName: widget.contactName,
          phoneNumber: widget.phoneNumber,
          isVideoCall: isVideo,
        ),
      ),
    );

    // Dynamic modern Call Logs added directly to your chat feed upon call termination!
    final duration = DateTime.now().difference(startTime);
    if (duration.inSeconds > 2) {
      final minutes = duration.inMinutes.toString().padLeft(2, '0');
      final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
      final callTypeLabel = isVideo ? "Video Call" : "Voice Call";
      final localMessage = {
        'id': 'system-call-${DateTime.now().microsecondsSinceEpoch}',
        'conversation_id': widget.conversationId,
        'sender_id': 'system',
        'sender_name': 'System',
        'message_text': '$callTypeLabel ended • $minutes:$seconds',
        'message_type': 'system',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      setState(() {
        _messages.add(localMessage);
      });
      _scrollToBottom();
    }
  }

  Widget _buildQuickSuggestions() {
    final contactId = widget.conversationId;
    List<String> suggestions = [];
    if (contactId == 'dr-chipo-moyo') {
      suggestions = [
        "Checking Bed 2 alarm log.",
        "Manual O2 cell check done.",
        "Routing backup cylinders."
      ];
    } else if (contactId == 'farai-gumbo') {
      suggestions = [
        "Running Evita valve calibration.",
        "Checking B2 replacement turbine.",
        "Pneumatic leak test passed."
      ];
    } else if (contactId == 'tendai-chidi') {
      suggestions = [
        "Manifold pressure verified at 4.2 bar.",
        "Reserve cylinders routing checked.",
        "Pipeline status is stable."
      ];
    } else if (contactId == 'dr-sekai-nzenza') {
      suggestions = [
        "ICU audit sheet is completed.",
        "High pressure alarm resolved.",
        "Technical log is uploaded."
      ];
    } else if (contactId == 'rufaro-moyo') {
      suggestions = [
        "Turbine inventory is restocked.",
        "Reviewing purchase requests.",
        "Drafting PM compliance logs."
      ];
    } else if (contactId == 'kudakwashe-hove') {
      suggestions = [
        "Bringing pH buffers to the lab.",
        "Drifting sensor verification done.",
        "pH calibration run successful."
      ];
    } else {
      suggestions = [
        "Understood, colleague.",
        "Checked. Logging now.",
        "Task completed."
      ];
    }

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: suggestions.length,
        itemBuilder: (context, idx) {
          final text = suggestions[idx];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              backgroundColor: Colors.white,
              elevation: 0,
              side: const BorderSide(color: AppTheme.border, width: 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              label: Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.secondary,
                ),
              ),
              onPressed: () {
                _msgCtrl.text = text;
                _sendMessage();
              },
            ),
          );
        },
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildTypingIndicatorBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 12, right: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
              child: Text(
                widget.contactName.substring(0, 1),
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 7,
                    height: 7,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${widget.contactName} is typing...",
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 150.ms).slideY(begin: 0.05, end: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: AppTheme.primary, size: 20),
            onPressed: () => Navigator.pop(context)),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
              child: Text(widget.contactName.substring(0, 1),
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.contactName,
                      style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                  if (widget.isOnline)
                    const Text("Online",
                        style: TextStyle(
                            color: AppTheme.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w600))
                  else if (widget.lastSeen != null)
                    Text("Last seen ${widget.lastSeen}",
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.video_camera_front_outlined,
                  color: AppTheme.primary),
              onPressed: () => _startCall(true)),
          IconButton(
              icon: const Icon(Icons.call_rounded, color: AppTheme.primary),
              onPressed: () => _startCall(false)),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // MESSAGES AREA
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) =>
                            _buildMessageBubble(_messages[index]),
                      ),
          ),

          if (_isTyping) _buildTypingIndicatorBubble(),

          // Dynamic Structured suggestions
          _buildQuickSuggestions(),

          // INPUT BAR (Professional Style)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                      icon: const Icon(Icons.add_box_outlined,
                          color: AppTheme.primary, size: 28),
                      onPressed: _showAttachmentOptions),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _msgCtrl,
                        onChanged: (val) {
                          ChatService.instance.sendTyping(
                              widget.conversationId, 'CURRENT-TECH');
                          setState(() {});
                        },
                        style: const TextStyle(
                            fontSize: 15, color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          hintText: "Message...",
                          hintStyle: TextStyle(color: AppTheme.textSecondary),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap:
                        _msgCtrl.text.trim().isNotEmpty ? _sendMessage : null,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: _msgCtrl.text.trim().isEmpty
                          ? AppTheme.neutral.withValues(alpha: 0.3)
                          : AppTheme.primary,
                      child: const Icon(Icons.north_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined,
                size: 54, color: AppTheme.neutral.withValues(alpha: 0.55)),
            const SizedBox(height: 16),
            const Text(
              'No messages yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Start with the equipment model, asset ID, alarm code, and current patient-safety status.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isSystem = msg['message_type'] == 'system';
    
    // RENDER SYSTEM EVENT CHIPS BEAUTIFULLY
    if (isSystem) {
      final text = msg['message_text']?.toString() ?? '';
      final isVideo = text.contains('Video');
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.muted,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.divider, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVideo ? Icons.video_camera_front_outlined : Icons.call_rounded,
                size: 13,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                text,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack);
    }

    final currentUserId = ChatService.instance.currentUserId;
    final senderId = msg['sender_id']?.toString();
    final isMe = senderId == currentUserId || senderId == 'local-technician';
    final deliveryState = msg['delivery_state']?.toString() ?? 'sent';
    final timestamp =
        DateTime.tryParse(msg['timestamp']?.toString() ?? '') ?? DateTime.now();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            if (!isMe)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg['message_text']?.toString() ?? '',
              style: TextStyle(
                  color: isMe ? Colors.white : AppTheme.textPrimary,
                  fontSize: 15,
                  height: 1.4),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(timestamp.toLocal()),
                  style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : AppTheme.textSecondary),
                ),
                if (isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      deliveryState == 'queued'
                          ? Icons.schedule_rounded
                          : Icons.done_all,
                      size: 14,
                      color: deliveryState == 'queued'
                          ? AppTheme.warning
                          : Colors.white70,
                    ),
                  ),
              ],
            )
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.05, end: 0);
  }
}
