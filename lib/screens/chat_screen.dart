import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/utils/animation_helper.dart';
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
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    ChatService.instance.joinRoom(widget.conversationId);
    
    // Listen for incoming messages
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
      Future.delayed(const Duration(milliseconds: 100), () => _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut));
    }
  }

  void _sendMessage() {
    if (_msgCtrl.text.trim().isEmpty) return;
    ChatService.instance.sendMessage({
      'conversation_id': widget.conversationId,
      // USES REAL IDENTIFIERS NOW
      'sender_id': ChatService.instance.currentUserId,
      'sender_name': ChatService.instance.currentUserName ?? 'Technician',
      'message_text': _msgCtrl.text.trim(),
      'message_type': 'text'
    });
    _msgCtrl.clear();
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(20),
        decoration: AppTheme.hudDecoration.copyWith(borderRadius: BorderRadius.circular(15)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primary),
              title: const Text("Open Camera", style: TextStyle(color: Colors.white, fontFamily: 'Share Tech Mono')),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.image, color: AppTheme.primary),
              title: const Text("Choose from Gallery", style: TextStyle(color: Colors.white, fontFamily: 'Share Tech Mono')),
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
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.primary), onPressed: () => Navigator.pop(context)),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primary.withOpacity(0.2),
              child: Text(widget.contactName.substring(0, 1), style: const TextStyle(color: AppTheme.primary, fontFamily: 'Orbitron')),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.contactName, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 16, color: Colors.white)),
                if (widget.isOnline) 
                  const Text("Online", style: TextStyle(color: AppTheme.accent, fontSize: 10, fontFamily: 'Share Tech Mono'))
                else if (widget.lastSeen != null)
                  Text("Last seen ${widget.lastSeen}", style: const TextStyle(color: AppTheme.textGrey, fontSize: 10, fontFamily: 'Share Tech Mono')),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam, color: AppTheme.primary), onPressed: () {}),
          IconButton(icon: const Icon(Icons.phone, color: AppTheme.primary), onPressed: () {}),
          const SizedBox(width: 5),
        ],
      ),
      body: ScanlineWrapper(
        child: Column(
          children: [
            // MESSAGES AREA
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(15),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  // RECOGNIZES YOUR REAL MESSAGES
                  bool isMe = msg['sender_id'] == ChatService.instance.currentUserId;
                  
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      decoration: BoxDecoration(
                        color: isMe ? AppTheme.primary.withOpacity(0.15) : AppTheme.bgLight,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(15),
                          topRight: const Radius.circular(15),
                          bottomLeft: Radius.circular(isMe ? 15 : 0),
                          bottomRight: Radius.circular(isMe ? 0 : 15),
                        ),
                        border: Border.all(color: isMe ? AppTheme.primary.withOpacity(0.5) : Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(msg['message_text'], style: const TextStyle(color: Colors.white, fontSize: 15)),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(DateFormat('HH:mm').format(DateTime.parse(msg['timestamp'] ?? DateTime.now().toIso8601String())), style: const TextStyle(fontSize: 10, color: AppTheme.textGrey)),
                              if (isMe) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.done_all, size: 14, color: AppTheme.primary)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ).animate().fadeIn().slideX(begin: isMe ? 0.1 : -0.1);
                },
              ),
            ),
            
            // NORMALIZED TYPING INDICATOR
            if (_isTyping)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, bottom: 10),
                  child: Row(
                    children: [
                      const Text("Typing", style: TextStyle(color: AppTheme.primary, fontSize: 12, fontStyle: FontStyle.italic)),
                      const SizedBox(width: 5),
                      const Icon(Icons.more_horiz, color: AppTheme.primary, size: 16).animate(onPlay: (c) => c.repeat()).fade(duration: 500.ms),
                    ],
                  ),
                ),
              ),

            // INPUT BAR (WhatsApp Style)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              color: AppTheme.bgLight,
              child: SafeArea(
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.attach_file, color: AppTheme.textGrey), onPressed: _showAttachmentOptions),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15), 
                        decoration: BoxDecoration(color: AppTheme.bgDark, borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.white10)),
                        child: TextField(
                          controller: _msgCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(hintText: "Type a message", hintStyle: TextStyle(color: AppTheme.textGrey), border: InputBorder.none),
                          onChanged: (_) {
                            ChatService.instance.sendTyping(widget.conversationId, 'TECH-CURRENT');
                            setState(() {}); 
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _msgCtrl.text.isNotEmpty ? _sendMessage : null,
                      onLongPress: () => setState(() => _isRecording = true),
                      onLongPressUp: () => setState(() => _isRecording = false),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.primary.withOpacity(0.8)),
                        child: Icon(_msgCtrl.text.isNotEmpty ? Icons.send : Icons.mic, color: Colors.black, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}