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

  // NEW: This now starts empty and populates from the real database!
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoadingContacts = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // NO LONGER HARDCODED! Uses the ID from the Login Screen.
    ChatService.instance.connect(ChatService.instance.currentUserId ?? 'UNKNOWN'); 
    
    _loadRealContacts(); // Fetch from DB on load
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
          "last_msg": "Chat started",
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
    // Refresh list right before opening
    _loadRealContacts();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select Contact", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ListTile(
              leading: const CircleAvatar(backgroundColor: AppTheme.primary, child: Icon(Icons.group, color: Colors.black)),
              title: const Text("New Group Chat", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Group creation coming soon.")));
              },
            ),
            const Divider(color: Colors.white10),
            
            // DYNAMIC LIST FROM SERVER
            if (_isLoadingContacts)
              const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            else if (_contacts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text("No other technicians registered yet.", style: TextStyle(color: AppTheme.textGrey)),
              )
            else
              ..._contacts.map((c) {
                bool isOnline = c['online'] == 1 || c['online'] == true;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary.withOpacity(0.2), 
                    child: Text(c['name'].toString().substring(0, 1).toUpperCase(), style: const TextStyle(color: AppTheme.primary))
                  ),
                  title: Text(c['name'], style: const TextStyle(color: Colors.white)),
                  subtitle: Text(isOnline ? "Online" : "Offline", style: TextStyle(color: isOnline ? AppTheme.accent : AppTheme.textGrey, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _startNewChat(c);
                  },
                );
              }),
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
      backgroundColor: AppTheme.bgDark,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Schedule Meeting", style: TextStyle(color: AppTheme.primary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(controller: topicCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Meeting Topic", labelStyle: const TextStyle(color: AppTheme.textGrey), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primary.withOpacity(0.5))), focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primary)))),
            const SizedBox(height: 20),
            Row(children: [Expanded(child: OutlinedButton.icon(onPressed: (){}, icon: const Icon(Icons.calendar_today), label: const Text("Today"))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: (){}, icon: const Icon(Icons.access_time), label: const Text("14:00")))]),
            const SizedBox(height: 30),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black), onPressed: () { if (topicCtrl.text.isNotEmpty) { setState(() { _meetings.add({"topic": topicCtrl.text, "time": "Today, 14:00", "host": "You"}); }); Navigator.pop(ctx); } }, child: const Text("Schedule Now", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _startInstantMeeting() => Navigator.push(context, MaterialPageRoute(builder: (_) => const MeetingRoomView(meetingTopic: "Instant Meeting")));

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppTheme.bgLight,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 10, top: 20, bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_isSearching)
                      Expanded(child: TextField(controller: _searchCtrl, autofocus: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Search...", hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none)))
                    else
                      const Text("Messages", style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        IconButton(icon: Icon(_isSearching ? Icons.close : Icons.search, color: AppTheme.primary), onPressed: () => setState(() { _isSearching = !_isSearching; if (!_isSearching) _searchCtrl.clear(); })),
                        PopupMenuButton<String>(icon: const Icon(Icons.more_vert, color: AppTheme.primary), color: AppTheme.bgDark, itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[const PopupMenuItem<String>(value: 'Settings', child: Text('Settings', style: TextStyle(color: Colors.white)))],),
                      ],
                    )
                  ],
                ),
              ),
              TabBar(controller: _tabController, indicatorColor: AppTheme.primary, labelColor: AppTheme.primary, unselectedLabelColor: AppTheme.textGrey, labelStyle: const TextStyle(fontWeight: FontWeight.bold), tabs: const [Tab(text: "CHATS"), Tab(text: "CALLS"), Tab(text: "MEETINGS")]),
            ],
          ),
        ),
        Expanded(child: TabBarView(controller: _tabController, children: [_buildChatList(), _buildCallHistory(), _buildMeetingsList()])),
      ],
    );
  }

  Widget _buildChatList() {
    return Stack(
      children: [
        if (_chats.isEmpty)
          Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.chat_bubble_outline, size: 60, color: AppTheme.primary.withOpacity(0.5)), const SizedBox(height: 20), const Text("No conversations yet.", style: TextStyle(color: Colors.white, fontSize: 16)), const SizedBox(height: 10), const Text("Tap + to start a chat.", style: TextStyle(color: AppTheme.textGrey))]).animate().fadeIn())
        else
          ListView.builder(
            itemCount: _chats.length,
            itemBuilder: (ctx, i) {
              final chat = _chats[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                leading: CircleAvatar(backgroundColor: AppTheme.primary.withOpacity(0.2), child: Text(chat['name'].substring(0, 1), style: const TextStyle(color: AppTheme.primary, fontSize: 20))),
                title: Text(chat['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(chat['last_msg'], style: const TextStyle(color: AppTheme.textGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Text(chat['time'], style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(conversationId: chat['id'], contactName: chat['name'], isOnline: chat['online']))); },
              );
            },
          ),
        Positioned(bottom: 20, right: 20, child: FloatingActionButton(heroTag: "new_chat", backgroundColor: AppTheme.primary, onPressed: _showNewChatPicker, child: const Icon(Icons.add, color: Colors.black)).animate().scale(delay: 500.ms, duration: 400.ms, curve: Curves.easeOutBack)),
      ],
    );
  }

  Widget _buildCallHistory() {
    return Stack(
      children: [
        if (_calls.isEmpty)
          Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.phone_missed, size: 60, color: AppTheme.primary.withOpacity(0.5)), const SizedBox(height: 20), const Text("No recent calls.", style: TextStyle(color: Colors.white, fontSize: 16))]).animate().fadeIn()),
        Positioned(bottom: 20, right: 20, child: FloatingActionButton(heroTag: "new_call", backgroundColor: AppTheme.primary, onPressed: _showNewChatPicker, child: const Icon(Icons.add_call, color: Colors.black)).animate().scale(delay: 500.ms, duration: 400.ms, curve: Curves.easeOutBack)),
      ],
    );
  }

  Widget _buildMeetingsList() {
    return Stack(
      children: [
        if (_meetings.isEmpty)
          Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.video_camera_front, size: 60, color: AppTheme.primary.withOpacity(0.5)), const SizedBox(height: 20), const Text("No upcoming meetings.", style: TextStyle(color: Colors.white, fontSize: 16))]).animate().fadeIn())
        else
          ListView.builder(
            padding: const EdgeInsets.only(top: 10), itemCount: _meetings.length,
            itemBuilder: (ctx, i) {
              final m = _meetings[i];
              return Card(margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), color: AppTheme.bgLight, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.white10)), child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.videocam, color: AppTheme.primary)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m['topic'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 5), Text("Scheduled: ${m['time']}", style: const TextStyle(color: AppTheme.textGrey, fontSize: 12))])), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), onPressed: _startInstantMeeting, child: const Text("Join"))])));
            },
          ),
        Positioned(bottom: 20, right: 20, child: Column(children: [FloatingActionButton.extended(heroTag: "schedule", backgroundColor: AppTheme.bgLight, icon: const Icon(Icons.calendar_month, color: AppTheme.primary), label: const Text("Schedule", style: TextStyle(color: AppTheme.primary)), onPressed: _showScheduleMeetingSheet), const SizedBox(height: 15), FloatingActionButton.extended(heroTag: "start", backgroundColor: AppTheme.primary, icon: const Icon(Icons.videocam, color: Colors.black), label: const Text("Start Now", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), onPressed: _startInstantMeeting)])),
      ],
    );
  }
}