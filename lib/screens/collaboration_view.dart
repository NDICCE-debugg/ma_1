import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/services/chat_service.dart';
import 'package:ma_1/screens/chat_screen.dart';
import 'package:ma_1/screens/meeting_room_view.dart';
import 'package:intl/intl.dart';

class CollaborationView extends StatefulWidget {
  const CollaborationView({super.key});

  @override
  State<CollaborationView> createState() => _CollaborationViewState();
}

class _CollaborationViewState extends State<CollaborationView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();

  final List<Map<String, dynamic>> _chats = [];
  final List<Map<String, dynamic>> _calls = [];
  final List<Map<String, dynamic>> _meetings = [];

  List<Map<String, dynamic>> _contacts = [];
  bool _isLoadingContacts = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Connect with current credentials
    ChatService.instance.connect(ChatService.instance.currentUserId ?? 'UNKNOWN'); 
    _loadRealContacts();
  }

  void _loadRealContacts() async {
    setState(() => _isLoadingContacts = true);
    final contacts = await ChatService.instance.getContacts();
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
          "last_msg": "Conversation started",
          "time": DateFormat('HH:mm').format(DateTime.now()),
          "unread": 0,
          "online": contact['online'] == 1 || contact['online'] == true
        });
      });
    }
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: contact['id'], 
          contactName: contact['name'],
          isOnline: contact['online'] == 1 || contact['online'] == true,
        )
      )
    );
  }

  void _showNewChatPicker() {
    _loadRealContacts();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("New Message", style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(backgroundColor: AppTheme.primary, child: Icon(Icons.group_outlined, color: Colors.white)),
              title: const Text("Create Group Chat", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Group feature pending update.")));
              },
            ),
            const Divider(height: 32),
            
            const Text("CONTACTS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 1)),
            const SizedBox(height: 12),
            if (_isLoadingContacts)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (_contacts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text("No registered technicians found.", style: TextStyle(color: AppTheme.textSecondary)),
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
                        child: Text(c['name'].toString().substring(0, 1).toUpperCase(), 
                          style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold))
                      ),
                      title: Text(c['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(isOnline ? "Active now" : "Offline", 
                        style: TextStyle(color: isOnline ? AppTheme.success : AppTheme.textSecondary, fontSize: 12)),
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

  void _showScheduleMeetingSheet() {
    final topicCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Schedule Clinical Meeting", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
              controller: topicCtrl, 
              decoration: const InputDecoration(labelText: "Meeting Agenda / Topic")
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: (){}, icon: const Icon(Icons.calendar_today, size: 16), label: const Text("Select Date"))),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton.icon(onPressed: (){}, icon: const Icon(Icons.access_time, size: 16), label: const Text("Set Time"))),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity, 
              height: 50, 
              child: ElevatedButton(
                onPressed: () { 
                  if (topicCtrl.text.isNotEmpty) { 
                    setState(() { 
                      _meetings.add({"topic": topicCtrl.text, "time": "Today, 14:00", "host": "You"}); 
                    }); 
                    Navigator.pop(ctx); 
                  } 
                }, 
                child: const Text("Schedule Meeting")
              )
            ),
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
                        Expanded(child: TextField(controller: _searchCtrl, autofocus: true, decoration: const InputDecoration(hintText: "Search contacts...", border: InputBorder.none, filled: false)))
                      else
                        const Text("Team Communication", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
                      Row(
                        children: [
                          IconButton(icon: Icon(_isSearching ? Icons.close : Icons.search, color: AppTheme.primary), onPressed: () => setState(() { _isSearching = !_isSearching; if (!_isSearching) _searchCtrl.clear(); })),
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
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [Tab(text: "CHATS"), Tab(text: "CALLS"), Tab(text: "MEETINGS")],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController, 
              children: [_buildChatList(), _buildCallHistory(), _buildMeetingsList()]
            )
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return Stack(
      children: [
        if (_chats.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: AppTheme.neutral.withOpacity(0.4)), 
                const SizedBox(height: 16), 
                const Text("No Active Conversations", style: TextStyle(color: AppTheme.textSecondary, fontSize: 16, fontWeight: FontWeight.w500)),
              ]
            ).animate().fadeIn()
          )
        else
          ListView.separated(
            itemCount: _chats.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 80, color: AppTheme.divider),
            itemBuilder: (ctx, i) {
              final chat = _chats[i];
              return ListTile(
                tileColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primary.withOpacity(0.1), 
                  child: Text(chat['name'].substring(0, 1), style: const TextStyle(color: AppTheme.primary, fontSize: 20, fontWeight: FontWeight.bold))
                ),
                title: Text(chat['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text(chat['last_msg'], style: const TextStyle(color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Text(chat['time'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(conversationId: chat['id'], contactName: chat['name'], isOnline: chat['online']))); },
              );
            },
          ),
        Positioned(
          bottom: 24, right: 20, 
          child: FloatingActionButton(
            heroTag: "new_chat", 
            backgroundColor: AppTheme.primary, 
            onPressed: _showNewChatPicker, 
            child: const Icon(Icons.chat_outlined, color: Colors.white)
          ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack)
        ),
      ],
    );
  }

  Widget _buildCallHistory() {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, 
            children: [
              Icon(Icons.phone_outlined, size: 64, color: AppTheme.neutral.withOpacity(0.4)), 
              const SizedBox(height: 16), 
              const Text("No Recent Calls", style: TextStyle(color: AppTheme.textSecondary, fontSize: 16, fontWeight: FontWeight.w500))
            ]
          ).animate().fadeIn()
        ),
        Positioned(
          bottom: 24, right: 20, 
          child: FloatingActionButton(
            heroTag: "new_call", 
            backgroundColor: AppTheme.secondary, 
            onPressed: _showNewChatPicker, 
            child: const Icon(Icons.add_call, color: Colors.white)
          )
        ),
      ],
    );
  }

  Widget _buildMeetingsList() {
    return Stack(
      children: [
        if (_meetings.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                Icon(Icons.video_camera_back_outlined, size: 64, color: AppTheme.neutral.withOpacity(0.4)), 
                const SizedBox(height: 16), 
                const Text("No Upcoming Consultations", style: TextStyle(color: AppTheme.textSecondary, fontSize: 16, fontWeight: FontWeight.w500))
              ]
            ).animate().fadeIn()
          )
        else
          ListView.builder(
            padding: const EdgeInsets.all(16), 
            itemCount: _meetings.length,
            itemBuilder: (ctx, i) {
              final m = _meetings[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16), 
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12), 
                        decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12)), 
                        child: const Icon(Icons.videocam_outlined, color: AppTheme.primary)
                      ), 
                      const SizedBox(width: 16), 
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            Text(m['topic'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), 
                            const SizedBox(height: 4), 
                            Text("Scheduled: ${m['time']}", style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))
                          ]
                        )
                      ), 
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary, 
                          padding: const EdgeInsets.symmetric(horizontal: 16)
                        ), 
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MeetingRoomView(meetingTopic: "Consultation"))), 
                        child: const Text("Join")
                      )
                    ]
                  )
                )
              );
            },
          ),
        Positioned(
          bottom: 24, right: 20, 
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.extended(
                heroTag: "schedule", 
                backgroundColor: Colors.white, 
                icon: const Icon(Icons.calendar_today_outlined, color: AppTheme.primary, size: 18), 
                label: const Text("Schedule", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)), 
                onPressed: _showScheduleMeetingSheet
              ), 
              const SizedBox(height: 16), 
              FloatingActionButton.extended(
                heroTag: "start", 
                backgroundColor: AppTheme.primary, 
                icon: const Icon(Icons.video_call, color: Colors.white), 
                label: const Text("Start Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MeetingRoomView(meetingTopic: "Instant Consultation")))
              )
            ]
          )
        ),
      ],
    );
  }
}