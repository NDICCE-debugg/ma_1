import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/services/chat_service.dart';

class MeetingRoomView extends StatefulWidget {
  final String meetingTopic;
  const MeetingRoomView({super.key, required this.meetingTopic});

  @override
  State<MeetingRoomView> createState() => _MeetingRoomViewState();
}

class _MeetingRoomViewState extends State<MeetingRoomView> {
  bool _isChatOpen = false;
  bool _isMuted = false;
  bool _isCameraOn = true;

  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _chatScrollCtrl = ScrollController();
  final ScrollController _notesScrollCtrl = ScrollController();

  // Real-time local meeting message log
  final List<Map<String, String>> _meetingMessages = [];

  final List<Map<String, String>> _detectedNotes = [];

  // Professional clinical participant list
  final List<String> _participants = [
    "You",
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _chatScrollCtrl.dispose();
    _notesScrollCtrl.dispose();
    super.dispose();
  }

  void _sendMeetingMessage() {
    if (_msgCtrl.text.trim().isEmpty) return;
    final text = _msgCtrl.text.trim();
    final note = _noteFromTranscript({
      "sender": "You",
      "text": text,
    });
    setState(() {
      _meetingMessages.add({
        "sender": "You",
        "text": text,
      });
      _detectedNotes.insert(0, note);
    });
    _msgCtrl.clear();
    _scrollChatToBottom();
    _scrollNotesToTop();

    ChatService.instance.addCallNote({
      "id": "CALL-${DateTime.now().millisecondsSinceEpoch % 10000}",
      "equipment": widget.meetingTopic,
      "technician": "You",
      "date": "Today, ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
      "issue": "Live Call Note (${note['type']}): ${note['text']}",
      "notes": text,
    });
  }

  Map<String, String> _noteFromTranscript(Map<String, String> message) {
    final text = message["text"] ?? "";
    final lower = text.toLowerCase();
    final type = lower.contains("decision")
        ? "Decision"
        : lower.contains("risk") || lower.contains("do not")
            ? "Risk"
            : lower.contains("follow up") || lower.contains("action")
                ? "Action"
                : "Note";
    return {
      "type": type,
      "text": text
          .replaceFirst(
              RegExp(r'^(Action item|Decision|Risk noted|Follow up):\s*',
                  caseSensitive: false),
              '')
          .trim(),
      "source": "From ${message["sender"] ?? "meeting audio"}",
    };
  }

  void _scrollChatToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(
          _chatScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollNotesToTop() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_notesScrollCtrl.hasClients) {
        _notesScrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --- FLOATING CALL NOTES DIALOG (Taken Call Transcripts) ---
  void _showCallNotesHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Indicator handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.assignment_turned_in_outlined,
                          color: AppTheme.primary, size: 24),
                      SizedBox(width: 10),
                      Text("Clinical Call Transcripts",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                              fontFamily: 'Outfit')),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Text(
                  "Live detected notes plus archived transcripts summarizing clinical hardware decisions.",
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontFamily: 'Outfit')),
              const SizedBox(height: 20),

              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: ChatService.instance.getCallNotes(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final notesList = snapshot.data!;
                    return ListView(
                      controller: scrollController,
                      children: [
                        ..._detectedNotes.map(_buildDetectedNoteCard),
                        const SizedBox(height: 8),
                        if (notesList.isNotEmpty) ...[
                          const Divider(height: 28, color: AppTheme.divider),
                          ...notesList.map((note) => _buildCallNoteCard(
                                callId: note['id'] ?? '#CALL-NEW',
                                equipment: note['equipment'] ?? 'Medical Device',
                                technician: note['technician'] ?? 'Technician',
                                date: note['date'] ?? 'Just now',
                                issue: note['issue'] ?? '',
                                notes: note['notes'] ?? '',
                              )),
                        ],
                      ],
                    );
                  }
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallNoteCard({
    required String callId,
    required String equipment,
    required String technician,
    required String date,
    required String issue,
    required String notes,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppTheme.iceBlue.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(callId,
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        fontFamily: 'Outfit')),
              ),
              Text(date,
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Outfit')),
            ],
          ),
          const SizedBox(height: 12),
          Text(equipment,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppTheme.primary,
                  fontFamily: 'Outfit')),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.person_pin_outlined,
                  size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text("Logged by: $technician",
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const Divider(height: 20, color: AppTheme.divider),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                  height: 1.4,
                  fontFamily: 'Outfit'),
              children: [
                const TextSpan(
                    text: "Issue Raised: ",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: "$issue\n\n"),
                const TextSpan(
                    text: "Diagnostic Notes: ",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondary)),
                TextSpan(
                    text: notes,
                    style: const TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedNoteCard(Map<String, String> note) {
    final type = note["type"] ?? "Note";
    final color = switch (type) {
      "Decision" => AppTheme.success,
      "Risk" => AppTheme.error,
      "Action" => AppTheme.secondary,
      _ => AppTheme.primary,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note["text"] ?? "",
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    height: 1.35,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  note["source"] ?? "Detected during call",
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: AppTheme.primary, size: 20),
            onPressed: () => Navigator.pop(context)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.meetingTopic,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit')),
            const Text("Google Meet Clinical Consultation Session",
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Outfit')),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppTheme.divider, height: 1.0),
        ),
        actions: [
          // Styled Call Notes Action Button
          IconButton(
            tooltip: "Taken Call Notes",
            icon: const Icon(Icons.assignment_outlined,
                color: AppTheme.secondary),
            onPressed: _showCallNotesHistory,
          ),
          IconButton(
              tooltip: "Toggle Meet Chat",
              icon: Icon(_isChatOpen ? Icons.chat : Icons.chat_bubble_outline,
                  color: AppTheme.primary),
              onPressed: () {
                setState(() => _isChatOpen = !_isChatOpen);
                if (_isChatOpen) _scrollChatToBottom();
              }),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // MAIN VIDEO GRID
          Padding(
            padding: EdgeInsets.only(
              right: _isChatOpen ? MediaQuery.of(context).size.width * 0.35 : 0,
              bottom: 80, // Space for bottom bar
            ),
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _participants.length > 2 ? 2 : 1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: _participants.length,
              itemBuilder: (ctx, i) {
                final name = _participants[i];
                final isMuted = name == "You" ? _isMuted : false;
                return _buildVideoCard(name, false, isMuted);
              },
            ),
          ),

          // SIDE CHAT PANEL (Fully Interactive Chat Pane)
          if (_isChatOpen)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.35,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                      left: BorderSide(color: AppTheme.divider, width: 1.5)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      color: AppTheme.background,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded,
                                    size: 16, color: AppTheme.primary),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Consultation Chat",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        fontFamily: 'Outfit'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                size: 16, color: AppTheme.textSecondary),
                            onPressed: () =>
                                setState(() => _isChatOpen = false),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        controller: _chatScrollCtrl,
                        padding: const EdgeInsets.all(12),
                        itemCount: _meetingMessages.length,
                        itemBuilder: (ctx, idx) {
                          final msg = _meetingMessages[idx];
                          return _buildMiniChatBubble(
                              msg['sender']!, msg['text']!);
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border:
                            Border(top: BorderSide(color: AppTheme.divider)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _msgCtrl,
                              style: const TextStyle(
                                  fontSize: 13, fontFamily: 'Outfit'),
                              decoration: InputDecoration(
                                hintText: "Message...",
                                hintStyle: const TextStyle(
                                    fontSize: 13, color: AppTheme.neutral),
                                filled: true,
                                fillColor: AppTheme.background,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide.none),
                              ),
                              onSubmitted: (_) => _sendMeetingMessage(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _sendMeetingMessage,
                            child: const CircleAvatar(
                              radius: 18,
                              backgroundColor: AppTheme.primary,
                              child: Icon(Icons.send_rounded,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),

          // BOTTOM CONTROL BAR (Clean Medical Floating Bar)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 90,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, -2))
                ],
                border: const Border(top: BorderSide(color: AppTheme.divider)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlBtn(Icons.screen_share_outlined, "Share"),
                  _buildControlBtn(
                      Icons.assignment_turned_in_outlined, "Taken Notes",
                      onTap: _showCallNotesHistory),
                  _buildControlBtn(
                      _isCameraOn
                          ? Icons.videocam_outlined
                          : Icons.videocam_off_outlined,
                      "Camera",
                      onTap: () => setState(() => _isCameraOn = !_isCameraOn),
                      isActive: _isCameraOn),
                  _buildControlBtn(
                      _isMuted
                          ? Icons.mic_off_outlined
                          : Icons.mic_none_outlined,
                      "Mic",
                      onTap: () => setState(() => _isMuted = !_isMuted),
                      isActive: !_isMuted),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Text("Leave Call",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit')),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildVideoCard(String name, bool isActive, bool isMuted) {
    final showCameraFeed = name == "You" && _isCameraOn;
    return Container(
      decoration: BoxDecoration(
        color: showCameraFeed ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isActive ? AppTheme.secondary : AppTheme.divider,
            width: isActive ? 2 : 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Stack(
        children: [
          if (showCameraFeed)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                      border: Border.all(color: Colors.white24, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.videocam_rounded,
                      color: Colors.white70,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Secure Camera Stream Active",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            )
          else
            Center(
                child: CircleAvatar(
                    radius: 32,
                    backgroundColor: AppTheme.background,
                    child: Text(name.substring(0, 1),
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit')))),
          // Name Tag Pill
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isMuted)
                    const Icon(Icons.mic_off_rounded,
                        color: Colors.white, size: 12),
                  if (isMuted) const SizedBox(width: 4),
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Outfit')),
                ],
              ),
            ),
          ),
          // Active Speaker Indicator
          if (isActive)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: AppTheme.secondary,
                    borderRadius: BorderRadius.circular(6)),
                child: const Text("SPEAKING",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit')),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildControlBtn(IconData icon, String label,
      {VoidCallback? onTap, bool isActive = true}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: isActive ? AppTheme.primary : AppTheme.textSecondary,
              size: 24),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Outfit')),
        ],
      ),
    );
  }

  Widget _buildMiniChatBubble(String sender, String text) {
    bool isMe = sender == "You";
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(sender,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.secondary,
                  fontFamily: 'Outfit')),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isMe
                  ? AppTheme.primary.withValues(alpha: 0.08)
                  : AppTheme.background,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isMe ? 12 : 2),
                bottomRight: Radius.circular(isMe ? 2 : 12),
              ),
              border: Border.all(
                  color: isMe
                      ? AppTheme.primary.withValues(alpha: 0.2)
                      : AppTheme.divider),
            ),
            child: Text(text,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textPrimary,
                    fontFamily: 'Outfit')),
          ),
        ],
      ),
    );
  }
}
