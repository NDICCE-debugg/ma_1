import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/services/chat_service.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final FocusNode _msgFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _msgFocus.addListener(() {
      if (mounted) setState(() {});
    });
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
    _msgFocus.dispose();
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
        (messages.isNotEmpty &&
            _messages.isNotEmpty &&
            messages.last['id'] != _messages.last['id'])) {
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
      'recipient_name': widget.contactName,
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

  Future<void> _placePhoneCall() async {
    final phone = _normalizedPhone(widget.phoneNumber);
    if (phone == null) {
      _showCallMessage('No phone number is saved for ${widget.contactName}.');
      return;
    }

    final bool launched;
    try {
      launched = await launchUrl(
        Uri(scheme: 'tel', path: phone),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      if (!mounted) return;
      _showCallMessage('Could not open the phone dialer on this device.');
      return;
    }

    if (!mounted) return;
    _showCallMessage(
      launched
          ? 'Opening phone dialer for ${widget.contactName}.'
          : 'Could not open the phone dialer on this device.',
    );
  }

  String? _normalizedPhone(String? value) {
    final phone = value?.replaceAll(RegExp(r'[^\d+]'), '').trim() ?? '';
    return phone.isEmpty ? null : phone;
  }

  Future<void> _launchWhatsAppChat(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '').trim();
    if (cleanPhone.isEmpty) {
      _showCallMessage('Invalid phone number for WhatsApp.');
      return;
    }
    
    final digitsOnly = cleanPhone.replaceAll('+', '');
    final Uri waUri = Uri.parse("https://wa.me/$digitsOnly");
    try {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch WhatsApp: $e");
      _showCallMessage('Could not open WhatsApp on this device.');
    }
  }

  void _showCallMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
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
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.primary),
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
          if (widget.phoneNumber != null && widget.phoneNumber!.isNotEmpty) ...[
            IconButton(
                tooltip: "WhatsApp Chat",
                icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366)),
                onPressed: () => _launchWhatsAppChat(widget.phoneNumber!)),
            const SizedBox(width: 4),
          ],
          IconButton(
              icon: const Icon(Icons.call_rounded, color: AppTheme.primary),
              onPressed: _placePhoneCall),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildConversationContext(),
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

          _buildMessageComposer(),
        ],
      ),
    );
  }

  Widget _buildConversationContext() {
    final phone = widget.phoneNumber?.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.iceBlue.withValues(alpha: 0.16),
        border: const Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.health_and_safety_outlined,
                color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              [
                'Clinical engineering chat',
                if (phone != null && phone.isNotEmpty) phone,
                'AI-simulated reply support'
              ].join('  -  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'Outfit',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageComposer() {
    final focused = _msgFocus.hasFocus;
    final canSend = _msgCtrl.text.trim().isNotEmpty && !_isSending;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            border: const Border(top: BorderSide(color: AppTheme.divider)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.deepBlue.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: focused || _msgCtrl.text.trim().isNotEmpty
                      ? SizedBox(
                          key: const ValueKey('composer-tools'),
                          height: 34,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _composerTemplateChip(
                                icon: Icons.qr_code_2_rounded,
                                label: 'Asset ID',
                                value: 'Asset ID: ',
                              ),
                              _composerTemplateChip(
                                icon: Icons.error_outline_rounded,
                                label: 'Fault code',
                                value: 'Fault code: ',
                              ),
                              _composerTemplateChip(
                                icon: Icons.health_and_safety_outlined,
                                label: 'Safety',
                                value: 'Patient safety status: ',
                              ),
                              _composerTemplateChip(
                                icon: Icons.schedule_rounded,
                                label: 'ETA',
                                value: 'ETA to resolve: ',
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('composer-empty')),
                ),
                if (focused || _msgCtrl.text.trim().isNotEmpty)
                  const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _composerIconButton(
                      tooltip: 'Attach evidence',
                      icon: Icons.add_rounded,
                      onTap: _showAttachmentOptions,
                      filled: true,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: focused
                              ? Colors.white
                              : AppTheme.muted.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: focused
                              ? [
                                  BoxShadow(
                                    color: AppTheme.secondary
                                        .withValues(alpha: 0.16),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ]
                              : null,
                        ),
                        child: TextField(
                          controller: _msgCtrl,
                          focusNode: _msgFocus,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          onChanged: (val) {
                            ChatService.instance.sendTyping(
                                widget.conversationId, 'CURRENT-TECH');
                            setState(() {});
                          },
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Asset, alarm code, action taken...',
                            hintStyle: TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          onSubmitted: (_) {
                            if (canSend) _sendMessage();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _composerIconButton(
                      tooltip: 'Insert voice note marker',
                      icon: Icons.mic_none_rounded,
                      onTap: () => _insertComposerText('Voice note: '),
                    ),
                    const SizedBox(width: 8),
                    AnimatedScale(
                      duration: const Duration(milliseconds: 160),
                      scale: canSend ? 1 : 0.96,
                      child: Tooltip(
                        message: canSend ? 'Send message' : 'Type a message',
                        child: InkWell(
                          onTap: canSend ? _sendMessage : null,
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: canSend
                                  ? AppTheme.primary
                                  : AppTheme.neutral.withValues(alpha: 0.24),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: canSend
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.24),
                                        blurRadius: 14,
                                        offset: const Offset(0, 8),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: _isSending
                                ? const Padding(
                                    padding: EdgeInsets.all(13),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.arrow_upward_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _composerIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: filled ? AppTheme.primary : AppTheme.muted,
            borderRadius: BorderRadius.circular(14),
            border:
                filled ? null : Border.all(color: AppTheme.divider, width: 1),
          ),
          child: Icon(
            icon,
            color: filled ? Colors.white : AppTheme.secondary,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _composerTemplateChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 15, color: AppTheme.secondary),
        label: Text(label),
        labelStyle: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
        backgroundColor: AppTheme.iceBlue.withValues(alpha: 0.42),
        side: BorderSide(color: AppTheme.secondary.withValues(alpha: 0.12)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        onPressed: () => _insertComposerText(value),
      ),
    );
  }

  void _insertComposerText(String text) {
    final current = _msgCtrl.text;
    final next = current.trim().isEmpty ? text : '$current $text';
    _msgCtrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _msgFocus.requestFocus();
    setState(() {});
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
                isVideo
                    ? Icons.video_camera_front_outlined
                    : Icons.call_rounded,
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

    final bubble = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      decoration: BoxDecoration(
        color: isMe ? AppTheme.primary : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isMe ? 18 : 6),
          topRight: Radius.circular(isMe ? 6 : 18),
          bottomLeft: const Radius.circular(18),
          bottomRight: const Radius.circular(18),
        ),
        border: isMe ? null : Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: isMe ? 0.12 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            Text(
              msg['sender_name']?.toString() ?? widget.contactName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 5),
          ],
          Text(
            msg['message_text']?.toString() ?? '',
            style: TextStyle(
              color: isMe ? Colors.white : AppTheme.textPrimary,
              fontSize: 14.5,
              height: 1.42,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('HH:mm').format(timestamp.toLocal()),
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white70 : AppTheme.textSecondary,
                  fontFamily: 'Outfit',
                ),
              ),
              if (isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: Icon(
                    deliveryState == 'queued'
                        ? Icons.schedule_rounded
                        : Icons.done_all_rounded,
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
    );

    return Padding(
      padding: EdgeInsets.only(left: isMe ? 48 : 0, right: isMe ? 0 : 48),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 15,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
              child: Text(
                widget.contactName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          bubble,
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.05, end: 0);
  }
}
