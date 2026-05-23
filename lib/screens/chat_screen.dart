import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String contactName;
  final bool isOnline;
  final String? lastSeen;

  const ChatScreen({
    super.key, 
    required this.conversationId, 
    required this.contactName,
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

  @override
  void initState() {
    super.initState();
    ChatService.instance.joinRoom(widget.conversationId);
    ChatService.instance.incomingMessage.addListener(_onMessageReceived);
    ChatService.instance.typingIndicator.addListener(_onTyping);
  }

  @override
  void dispose() {
    ChatService.instance.incomingMessage.removeListener(_onMessageReceived);
    ChatService.instance.typingIndicator.removeListener(_onTyping);
    super.dispose();
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
      Future.delayed(const Duration(milliseconds: 100), () => 
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, 
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut));
    }
  }

  void _sendMessage() {
    if (_msgCtrl.text.trim().isEmpty) return;
    ChatService.instance.sendMessage({
      'conversation_id': widget.conversationId,
      'sender_id': ChatService.instance.currentUserId,
      'sender_name': ChatService.instance.currentUserName ?? 'Technician',
      'message_text': _msgCtrl.text.trim(),
      'message_type': 'text'
    });
    _msgCtrl.clear();
    setState(() {});
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primary),
              title: const Text("Camera", style: TextStyle(fontFamily: 'Inter')),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined, color: AppTheme.primary),
              title: const Text("Gallery", style: TextStyle(fontFamily: 'Inter')),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined, color: AppTheme.primary),
              title: const Text("Document", style: TextStyle(fontFamily: 'Inter')),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.primary, size: 20), 
          onPressed: () => Navigator.pop(context)
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
              child: Text(widget.contactName.substring(0, 1), 
                style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.contactName, 
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  if (widget.isOnline) 
                    const Text("Online", style: TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.w600))
                  else if (widget.lastSeen != null)
                    Text("Last seen ${widget.lastSeen}", style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam_outlined, color: AppTheme.primary), onPressed: () {}),
          IconButton(icon: const Icon(Icons.phone_outlined, color: AppTheme.primary), onPressed: () {}),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // MESSAGES AREA
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                bool isMe = msg['sender_id'] == ChatService.instance.currentUserId;
                
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isMe ? AppTheme.primary : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                      boxShadow: [
                        if (!isMe) BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(msg['message_text'], 
                          style: TextStyle(color: isMe ? Colors.white : AppTheme.textPrimary, fontSize: 15, height: 1.4)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('HH:mm').format(DateTime.parse(msg['timestamp'] ?? DateTime.now().toIso8601String())), 
                              style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : AppTheme.textSecondary)
                            ),
                            if (isMe) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.done_all, size: 14, color: Colors.white70)),
                          ],
                        )
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.05, end: 0);
              },
            ),
          ),
          
          if (_isTyping)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 12),
                child: Text("${widget.contactName} is typing...", 
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
              ),
            ),

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
                    icon: const Icon(Icons.add_circle_outline, color: AppTheme.primary, size: 28), 
                    onPressed: _showAttachmentOptions
                  ),
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
                          ChatService.instance.sendTyping(widget.conversationId, 'CURRENT-TECH');
                          setState(() {});
                        },
                        style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
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
                    onTap: _msgCtrl.text.trim().isNotEmpty ? _sendMessage : null,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: _msgCtrl.text.trim().isEmpty ? AppTheme.neutral.withValues(alpha: 0.3) : AppTheme.primary,
                      child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
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
}