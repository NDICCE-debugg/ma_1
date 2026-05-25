import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/services/chat_service.dart';
import 'package:ma_1/screens/chat_screen.dart';
import 'package:intl/intl.dart';
import 'package:ma_1/services/google_chat_service.dart';
import 'package:url_launcher/url_launcher.dart';

class CollaborationView extends StatefulWidget {
  const CollaborationView({super.key});

  @override
  State<CollaborationView> createState() => _CollaborationViewState();
}

class _CollaborationViewState extends State<CollaborationView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _calls = [];
  List<Map<String, dynamic>> _meetings = [];

  List<Map<String, dynamic>> _contacts = [];
  bool _isLoadingContacts = false;
  bool _isLoadingConversations = false;

  bool _isGenerating = false;
  String? _generatedMeetLink;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Connect with current credentials
    ChatService.instance
        .connect(ChatService.instance.currentUserId ?? 'UNKNOWN');
    _loadCommsData();
  }

  Future<void> _loadCommsData() async {
    setState(() {
      _isLoadingContacts = true;
      _isLoadingConversations = true;
    });
    final results = await Future.wait([
      ChatService.instance.getContacts(),
      ChatService.instance.getConversations(),
      ChatService.instance.getCallLogs(),
      ChatService.instance.getMeetings(),
    ]);
    if (!mounted) return;
    setState(() {
      _contacts = results[0];
      _chats = results[1];
      _calls = results[2];
      _meetings = results[3];
      _isLoadingContacts = false;
      _isLoadingConversations = false;
    });
  }

  void _loadRealContacts() async {
    setState(() => _isLoadingContacts = true);
    final contacts = await ChatService.instance.getContacts();
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _isLoadingContacts = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _startNewChat(Map<String, dynamic> contact) {
    if (!_chats.any((c) => c['id'] == contact['id'])) {
      setState(() {
        _chats.insert(0, {
          "id": contact['id'],
          "name": contact['name'],
          "last_message": "Conversation started",
          "last_message_time": DateTime.now().toUtc().toIso8601String(),
          "unread": 0,
          "online": contact['online'] == 1 || contact['online'] == true,
          "role": contact['role'] ?? contact['reg_number'] ?? "Technician",
        });
      });
    }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ChatScreen(
                  conversationId: contact['id'],
                  contactName: contact['name'],
                  phoneNumber: contact['phone']?.toString(),
                  isOnline: contact['online'] == 1 || contact['online'] == true,
                )));
  }

  Future<void> _placePhoneCall(Map<String, dynamic> contact) async {
    final phone = _normalizedPhone(contact['phone']?.toString());
    final name = contact['name']?.toString() ?? 'contact';

    if (phone == null) {
      _showCallMessage('No phone number is saved for $name.');
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
    if (launched) {
      await ChatService.instance.addCallLog({
        "name": name,
        "type": "voice",
        "direction": "outgoing",
        "time": "Today, ${DateFormat('HH:mm').format(DateTime.now())}",
        "status": "Dialer opened",
        "phone": phone,
        "online": contact['online'] == true || contact['online'] == 1,
      });
      _loadCommsData();
    }

    _showCallMessage(
      launched
          ? 'Opening phone dialer for $name.'
          : 'Could not open the phone dialer on this device.',
    );
  }

  String? _normalizedPhone(String? value) {
    final phone = value?.replaceAll(RegExp(r'[^\d+]'), '').trim() ?? '';
    return phone.isEmpty ? null : phone;
  }

  void _showCallMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<bool> _openGoogleMeet({
    String? meetingUrl,
    String topic = 'Instant Google Meet',
  }) async {
    final target = (meetingUrl != null && meetingUrl.trim().isNotEmpty)
        ? meetingUrl.trim()
        : 'https://meet.google.com/new';

    final bool launched;
    try {
      launched = await launchUrl(
        Uri.parse(target),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (_) {
      if (!mounted) return false;
      _showCallMessage('Could not open Google Meet on this device.');
      return false;
    }

    if (!mounted) return launched;
    _showCallMessage(
      launched
          ? 'Opening Google Meet for $topic.'
          : 'Could not open Google Meet on this device.',
    );
    return launched;
  }

  void _showNewChatPicker() {
    _loadRealContacts();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("New Message",
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: AppTheme.primary,
                  child: Icon(Icons.groups_2_outlined, color: Colors.white)),
              title: const Text("Create Group Chat",
                  style: TextStyle(
                      color: AppTheme.primary, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Group feature pending update.")));
              },
            ),
            const Divider(height: 32),
            const Text("CONTACTS",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                    letterSpacing: 1)),
            const SizedBox(height: 12),
            if (_isLoadingContacts)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator()))
            else if (_contacts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text("No registered technicians found.",
                    style: TextStyle(color: AppTheme.textSecondary)),
              )
            else
              Expanded(
                child: ListView(
                  children: _contacts.map((c) {
                    bool isOnline = c['online'] == 1 || c['online'] == true;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                          backgroundColor: AppTheme.background,
                          child: Text(
                              c['name']
                                  .toString()
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold))),
                      title: Text(c['name'],
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          [
                            c['role'] ?? c['reg_number'],
                            c['phone'],
                            isOnline ? 'Active now' : 'Offline',
                          ]
                              .where((value) =>
                                  value != null &&
                                  value.toString().trim().isNotEmpty)
                              .join(' - '),
                          style: TextStyle(
                              color: isOnline
                                  ? AppTheme.success
                                  : AppTheme.textSecondary,
                              fontSize: 12)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _startNewChat(c);
                      },
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showNewCallPicker() {
    _loadRealContacts();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Start Call",
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_isLoadingContacts)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator()))
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _contacts.map((c) {
                    final isOnline = c['online'] == 1 || c['online'] == true;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor:
                            AppTheme.primary.withValues(alpha: 0.08),
                        child: Text(
                            c['name'].toString().substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold)),
                      ),
                      title: Text(c['name'],
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          [
                            c['phone'],
                            isOnline
                                ? "Available now"
                                : "Offline - call can still be placed",
                          ]
                              .where((value) =>
                                  value != null &&
                                  value.toString().trim().isNotEmpty)
                              .join(' - '),
                          style: TextStyle(
                              color: isOnline
                                  ? AppTheme.success
                                  : AppTheme.textSecondary,
                              fontSize: 12)),
                      trailing: IconButton.filled(
                        tooltip: "Phone call",
                        icon: const Icon(Icons.call_rounded),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _placePhoneCall(c);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showScheduleMeetingSheet() {
    final topicCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Schedule Clinical Meeting",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
                controller: topicCtrl,
                decoration:
                    const InputDecoration(labelText: "Meeting Agenda / Topic")),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: const Text("Select Date"))),
                const SizedBox(width: 12),
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.access_time, size: 16),
                        label: const Text("Set Time"))),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                    onPressed: () async {
                      if (topicCtrl.text.isNotEmpty) {
                        final newMeeting = {
                          "topic": topicCtrl.text,
                          "time":
                              "Today, ${DateFormat('HH:mm').format(DateTime.now())}",
                          "host": "You",
                          "join_url": "https://meet.google.com/new",
                        };
                        await ChatService.instance.addMeeting(newMeeting);

                        final sentToGoogleChat =
                            await GoogleChatService.instance.sendMeetingCard(
                          topic: topicCtrl.text,
                          time: newMeeting['time']!,
                          host: 'Clinical Coordinator',
                          joinUrl: newMeeting['join_url']!,
                        );

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        _loadCommsData();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(sentToGoogleChat
                                ? 'Clinical meeting scheduled and sent to Google Chat.'
                                : 'Clinical meeting scheduled. Google Chat is not configured.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: const Text("Schedule Meeting"))),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 10, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_isSearching)
                        Expanded(
                            child: TextField(
                                controller: _searchCtrl,
                                autofocus: true,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                    hintText:
                                        "Search contacts, calls, meetings...",
                                    border: InputBorder.none,
                                    filled: false)))
                      else
                        const Expanded(
                            child: Text("Team Communication",
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryDark))),
                      Row(
                        children: [
                          IconButton(
                              icon: Icon(
                                  _isSearching ? Icons.close : Icons.search,
                                  color: AppTheme.primary),
                              onPressed: () => setState(() {
                                    _isSearching = !_isSearching;
                                    if (!_isSearching) _searchCtrl.clear();
                                  })),
                          IconButton(
                              icon: const Icon(Icons.refresh_rounded,
                                  color: AppTheme.primary),
                              onPressed: _loadCommsData),
                        ],
                      )
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.primary,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: AppTheme.textSecondary,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(text: "CHATS"),
                    Tab(text: "CALLS"),
                    Tab(text: "MEETINGS")
                  ],
                ),
              ],
            ),
          ),
          Expanded(
              child: TabBarView(controller: _tabController, children: [
            _buildChatList(),
            _buildCallHistory(),
            _buildMeetingsList()
          ])),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    final query = _searchCtrl.text.trim().toLowerCase();
    final chats = query.isEmpty
        ? _chats
        : _chats.where((chat) {
            return chat['name'].toString().toLowerCase().contains(query) ||
                (chat['last_message'] ?? chat['last_msg'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(query);
          }).toList();

    return Stack(
      children: [
        if (_isLoadingConversations)
          const Center(child: CircularProgressIndicator())
        else if (chats.isEmpty)
          Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Icon(Icons.forum_outlined,
                    size: 64, color: AppTheme.neutral.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                const Text("No Active Conversations",
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500)),
              ]).animate().fadeIn())
        else
          ListView.separated(
            padding: const EdgeInsets.only(top: 8, bottom: 88),
            itemCount: chats.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 80, color: AppTheme.divider),
            itemBuilder: (ctx, i) {
              final chat = chats[i];
              final unread = chat['unread'] as int? ?? 0;
              final lastMessage =
                  chat['last_message'] ?? chat['last_msg'] ?? '';
              final lastTime = _formatConversationTime(
                  chat['last_message_time'] ?? chat['time']);
              return ListTile(
                tileColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    child: Text(chat['name'].substring(0, 1),
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold))),
                title: Row(
                  children: [
                    Expanded(
                        child: Text(chat['name'],
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16))),
                    if (chat['online'] == true)
                      Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: AppTheme.success, shape: BoxShape.circle)),
                  ],
                ),
                subtitle: Text(lastMessage.toString(),
                    style: const TextStyle(color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(lastTime,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                    if (unread > 0) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text('$unread',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ChatScreen(
                              conversationId: chat['id'],
                              contactName: chat['name'],
                              phoneNumber: chat['phone']?.toString(),
                              isOnline: chat['online'])));
                },
              );
            },
          ),
        Positioned(
            bottom: 24,
            right: 20,
            child: FloatingActionButton(
                    heroTag: "new_chat",
                    backgroundColor: AppTheme.primary,
                    onPressed: _showNewChatPicker,
                    child: const Icon(Icons.edit_square, color: Colors.white))
                .animate()
                .scale(duration: 300.ms, curve: Curves.easeOutBack)),
      ],
    );
  }

  String _formatConversationTime(dynamic value) {
    if (value == null) return '';
    final raw = value.toString();
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final now = DateTime.now();
    if (DateUtils.isSameDay(local, now)) {
      return DateFormat('HH:mm').format(local);
    }
    if (DateUtils.isSameDay(local, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return DateFormat('MMM d').format(local);
  }

  Widget _buildCallHistory() {
    return Stack(
      children: [
        if (_calls.isEmpty)
          Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Icon(Icons.call_rounded,
                    size: 64, color: AppTheme.neutral.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                const Text("No Recent Calls",
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500))
              ]).animate().fadeIn())
        else
          ListView.separated(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: _calls.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 80, color: AppTheme.divider),
            itemBuilder: (ctx, i) {
              final call = _calls[i];
              final isMissed = call['direction'] == 'missed';
              final isIncoming = call['direction'] == 'incoming';

              IconData directionIcon;
              Color directionColor;
              if (isMissed) {
                directionIcon = Icons.call_missed;
                directionColor = AppTheme.error;
              } else if (isIncoming) {
                directionIcon = Icons.call_received;
                directionColor = AppTheme.success;
              } else {
                directionIcon = Icons.call_made;
                directionColor = AppTheme.primary;
              }

              return ListTile(
                tileColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    child: Text(call['name'].substring(0, 1),
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold))),
                title: Text(
                  call['name'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      Icon(directionIcon, size: 14, color: directionColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "${call['status']} - ${call['time']}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Call again',
                  icon:
                      const Icon(Icons.call_rounded, color: AppTheme.secondary),
                  onPressed: () => _placePhoneCall(call),
                ),
              );
            },
          ),
        Positioned(
            bottom: 24,
            right: 20,
            child: FloatingActionButton(
                heroTag: "new_call",
                backgroundColor: AppTheme.secondary,
                onPressed: _showNewCallPicker,
                child: const Icon(Icons.add_ic_call_rounded,
                    color: Colors.white))),
      ],
    );
  }

  void _generateClinicalMeetLink() async {
    setState(() {
      _isGenerating = true;
    });

    await Future.delayed(const Duration(milliseconds: 1600));

    setState(() {
      _isGenerating = false;
      _generatedMeetLink = "https://meet.google.com/new";
    });
  }

  Widget _buildMeetingsList() {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildMeetGeneratorCard(),
            const SizedBox(height: 24),
            const Row(
              children: [
                Icon(Icons.event_note_rounded,
                    size: 18, color: AppTheme.primary),
                SizedBox(width: 8),
                Text(
                  "Scheduled Consultations",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryDark,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_meetings.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.video_chat_outlined,
                        size: 48,
                        color: AppTheme.neutral.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    const Text(
                      "No Upcoming Consultations",
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Generate an instant link above to start immediately.",
                      style: TextStyle(color: AppTheme.neutral, fontSize: 12),
                    ),
                  ],
                ),
              ).animate().fadeIn()
            else
              ..._meetings.map((m) => _buildMeetingCard(m)),
            const SizedBox(
                height: 100), // padding at bottom so FAB doesn't cover content
          ],
        ),
        Positioned(
          bottom: 24,
          right: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.extended(
                heroTag: "schedule",
                backgroundColor: Colors.white,
                icon: const Icon(Icons.edit_calendar_rounded,
                    color: AppTheme.primary, size: 18),
                label: const Text("Schedule",
                    style: TextStyle(
                        color: AppTheme.primary, fontWeight: FontWeight.bold)),
                onPressed: _showScheduleMeetingSheet,
              ),
              const SizedBox(height: 16),
              FloatingActionButton.extended(
                heroTag: "start",
                backgroundColor: AppTheme.primary,
                icon: const Icon(Icons.video_camera_front_rounded,
                    color: Colors.white),
                label: const Text("Start Now",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  const joinUrl = 'https://meet.google.com/new';
                  final opened = await _openGoogleMeet(
                    meetingUrl: joinUrl,
                    topic: 'Instant Technical Consultation',
                  );
                  if (!opened) return;

                  final sentToGoogleChat =
                      await GoogleChatService.instance.sendMeetingCard(
                    topic: "Instant Technical Consultation Bridge",
                    time: "Started Now",
                    host: "Clinical Coordinator",
                    joinUrl: joinUrl,
                  );

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(sentToGoogleChat
                          ? 'Instant meeting started and sent to Google Chat.'
                          : 'Instant meeting started. Google Chat is not configured.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMeetingCard(Map<String, dynamic> m) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.video_camera_front_outlined,
                  color: AppTheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m['topic'],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          fontFamily: 'Outfit')),
                  const SizedBox(height: 4),
                  Text("Scheduled: ${m['time']}",
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontFamily: 'Outfit')),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: () => _openGoogleMeet(
                meetingUrl: m['join_url']?.toString(),
                topic: m['topic']?.toString() ?? 'Scheduled consultation',
              ),
              child: const Text("Join"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetGeneratorCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.midnightBlue, AppTheme.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.iceBlue.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              left: -40,
              bottom: -40,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.iceBlue.withValues(alpha: 0.04),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.iceBlue.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.personal_video_outlined,
                            color: AppTheme.iceBlue,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Google Meet Generator",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Instant clinical HD tele-consultation bridge",
                                style: TextStyle(
                                  color: AppTheme.iceBlue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (!_isGenerating && _generatedMeetLink == null) ...[
                      const Text(
                        "Need to consult with team experts immediately? Open Google Meet and let Google create the live consultation room.",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.iceBlue,
                            foregroundColor: AppTheme.midnightBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _generateClinicalMeetLink,
                          icon: const Icon(Icons.flash_on_rounded, size: 20),
                          label: const Text(
                            "Prepare Google Meet",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ).animate().shimmer(duration: 1500.ms, delay: 500.ms),
                      ),
                    ] else if (_isGenerating) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.iceBlue),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                "Provisioning Secure Clinical Uplink...",
                                style: TextStyle(
                                  color: AppTheme.iceBlue,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: const LinearProgressIndicator(
                              color: AppTheme.iceBlue,
                              backgroundColor: Colors.white12,
                              minHeight: 4,
                            ),
                          ).animate().shimmer(duration: 1000.ms),
                        ],
                      ),
                    ] else if (_generatedMeetLink != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.iceBlue.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_outline_rounded,
                                color: AppTheme.success, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _generatedMeetLink!,
                                style: const TextStyle(
                                  color: AppTheme.iceBlue,
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                    ClipboardData(text: _generatedMeetLink!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: AppTheme.midnightBlue,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    content: const Row(
                                      children: [
                                        Icon(Icons.check_circle,
                                            color: AppTheme.iceBlue, size: 20),
                                        SizedBox(width: 10),
                                        Text(
                                          "Meet link copied to clipboard!",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Outfit'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              child: const Icon(
                                Icons.copy_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white30),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _generatedMeetLink = null;
                                });
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text(
                                "Reset",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.success,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () => _openGoogleMeet(
                                meetingUrl: _generatedMeetLink,
                                topic: 'Instant HD Consultation',
                              ),
                              icon: const Icon(Icons.video_call_rounded,
                                  size: 18),
                              label: const Text(
                                "Launch Meet",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
