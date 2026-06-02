import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/services/chat_service.dart';
import 'package:ma_1/screens/chat_screen.dart';
import 'package:intl/intl.dart';
import 'package:ma_1/services/google_chat_service.dart';
import 'package:ma_1/utils/app_snackbar.dart';

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
  final TextEditingController _directChatPhoneCtrl = TextEditingController();

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

    final mockDecoys = {"Dr. Sekai Nzenza", "Dr. Chipo Moyo", "Farai Gumbo", "Tendai Chidi", "Rufaro Moyo"};
    final cleanCalls = results[2].where((c) => !mockDecoys.contains(c['name'])).toList();
    final cleanMeetings = results[3].where((m) => !mockDecoys.contains(m['host'])).toList();

    setState(() {
      _contacts = results[0];
      _chats = results[1];
      _calls = cleanCalls;
      _meetings = cleanMeetings;
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
    _directChatPhoneCtrl.dispose();
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

    final Uri telLaunchUri = Uri(
      scheme: 'tel',
      path: phone,
    );
    try {
      await launchUrl(telLaunchUri);
    } catch (e) {
      debugPrint("Could not launch phone dialer: $e");
    }

    await ChatService.instance.addCallLog({
      "name": name,
      "type": contact['type'] ?? "voice",
      "direction": "outgoing",
      "time": "Today, ${DateFormat('HH:mm').format(DateTime.now())}",
      "status": "Outgoing call placed",
      "phone": phone,
      "online": contact['online'] == true || contact['online'] == 1,
    });
    _loadCommsData();
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
    AppSnackBar.info(context, message);
  }

  Future<void> _joinSimulatedMeet(Map<String, dynamic> meeting) async {
    final topic = meeting['topic']?.toString() ?? 'Clinical Consultation';
    final joinUrl = meeting['join_url'] ?? "https://meet.google.com/new";

    final Uri meetUri = Uri.parse(joinUrl);
    try {
      await launchUrl(meetUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch Google Meet URL: $e");
    }

    await ChatService.instance.addMeeting({
      "topic": topic,
      "time": "Joined ${DateFormat('HH:mm').format(DateTime.now())}",
      "host": "You",
      "join_url": joinUrl,
      "status": "joined",
      "participants": meeting['participants'] ?? 5,
    });

    _loadCommsData();
  }

  void _showNewChatPicker() {
    _loadRealContacts();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final chatDialerCtrl = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24),
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
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: chatDialerCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: "Enter Phone Number...",
                        hintText: "+263 77 123 4567",
                        prefixIcon: const Icon(Icons.phone_iphone_rounded),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primary),
                          onPressed: () {
                            final number = chatDialerCtrl.text.trim();
                            if (number.isEmpty) {
                              AppSnackBar.warning(context, 'Please enter a phone number.');
                              return;
                            }
                            Navigator.pop(ctx);
                            
                            // Normalize typed phone number to compare
                            final cleanTyped = number.replaceAll(RegExp(r'[^\d+]'), '').trim();
                            
                            // Check if any registered user matches this phone number
                            final matchedUser = _contacts.firstWhere(
                              (c) {
                                final cPhone = c['phone']?.toString().replaceAll(RegExp(r'[^\d+]'), '').trim() ?? '';
                                return cPhone.isNotEmpty && cPhone == cleanTyped;
                              },
                              orElse: () => {},
                            );

                            if (matchedUser.isNotEmpty) {
                              _startNewChat(matchedUser);
                            } else {
                              final uuid = ChatService.instance.deterministicUuidFromPhone(cleanTyped);
                              final newDirect = {
                                "id": uuid,
                                "name": "Technician ($number)",
                                "phone": number,
                                "online": false,
                                "role": "Clinical Technician",
                              };
                              _startNewChat(newDirect);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      fixedSize: const Size(44, 44),
                    ),
                    tooltip: "Chat on WhatsApp",
                    icon: const Icon(Icons.chat_bubble_rounded, size: 20),
                    onPressed: () {
                      final number = chatDialerCtrl.text.trim();
                      if (number.isEmpty) {
                        AppSnackBar.warning(context, 'Please enter a phone number.');
                        return;
                      }
                      Navigator.pop(ctx);
                      _launchWhatsAppChat(number);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                    backgroundColor: AppTheme.primary,
                    child: Icon(Icons.groups_2_outlined, color: Colors.white)),
                title: const Text("Create Group Chat",
                    style: TextStyle(
                        color: AppTheme.primary, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  AppSnackBar.info(context, "Group feature pending update.");
                },
              ),
              const Divider(height: 24),
              const Text("CHOOSE FROM CONTACTS",
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
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (c['phone'] != null && c['phone'].toString().trim().isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366)),
                                tooltip: "Chat on WhatsApp",
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _launchWhatsAppChat(c['phone']);
                                },
                              ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textSecondary),
                          ],
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _startNewChat(c);
                        },
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showNewCallPicker() {
    _loadRealContacts();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final dialerCtrl = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24),
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
              TextField(
                controller: dialerCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "Enter Phone Number...",
                  hintText: "+263 77 123 4567",
                  prefixIcon: const Icon(Icons.dialpad_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.call_rounded, color: AppTheme.success),
                    onPressed: () async {
                      final number = dialerCtrl.text.trim();
                      if (number.isEmpty) {
                        AppSnackBar.warning(context, 'Please enter a phone number.');
                        return;
                      }
                      Navigator.pop(ctx);
                      final Uri telLaunchUri = Uri(
                        scheme: 'tel',
                        path: number.replaceAll(RegExp(r'[^\d+]'), ''),
                      );
                      try {
                        await launchUrl(telLaunchUri);
                      } catch (e) {
                        debugPrint("Could not launch phone dialer: $e");
                      }
                      await ChatService.instance.addCallLog({
                        "name": number,
                        "type": "voice",
                        "direction": "outgoing",
                        "time": "Today, ${DateFormat('HH:mm').format(DateTime.now())}",
                        "status": "Outgoing call placed",
                        "phone": number,
                        "online": false,
                      });
                      _loadCommsData();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text("CHOOSE FROM CONTACTS",
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
                          tooltip: "Mock call",
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
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showScheduleMeetingSheet() {
    final topicCtrl = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
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
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setSheetState(() {
                                  selectedDate = picked;
                                });
                              }
                            },
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(selectedDate == null
                                ? "Select Date"
                                : DateFormat('yyyy-MM-dd').format(selectedDate!)))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setSheetState(() {
                                  selectedTime = picked;
                                });
                              }
                            },
                            icon: const Icon(Icons.access_time, size: 16),
                            label: Text(selectedTime == null
                                ? "Set Time"
                                : selectedTime!.format(context)))),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                        onPressed: () async {
                          if (topicCtrl.text.isEmpty) {
                            AppSnackBar.warning(context, 'Please enter a meeting topic.');
                            return;
                          }

                          final date = selectedDate ?? DateTime.now();
                          final time = selectedTime ?? TimeOfDay.now();
                          final combinedDateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );

                          final String timeStr = DateFormat('MMM d, HH:mm').format(combinedDateTime);
                          final String joinUrl = ChatService.instance.generateMeetUrl();

                          final newMeeting = {
                            "topic": topicCtrl.text,
                            "time": timeStr,
                            "host": "You",
                            "join_url": joinUrl,
                            "status": "scheduled",
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

                          final msg = sentToGoogleChat
                              ? 'Clinical meeting scheduled and sent to Google Chat.'
                              : 'Clinical meeting scheduled. Google Chat is not configured.';
                          AppSnackBar.success(context, msg);
                        },
                        child: const Text("Schedule Meeting"))),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
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

  Widget _buildDirectChatInputCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.midnightBlue, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.midnightBlue.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.05),
            blurRadius: 1,
            spreadRadius: 1,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.iceBlue.withValues(alpha: 0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.iceBlue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.settings_ethernet_rounded,
                          color: AppTheme.iceBlue,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Direct Clinical Uplink",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                fontFamily: 'Outfit',
                                letterSpacing: 0.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Start immediate chat or route to secure WhatsApp bridge",
                              style: TextStyle(
                                color: AppTheme.iceBlue,
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.success,
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.phone_iphone_rounded,
                                size: 18,
                                color: AppTheme.iceBlue,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _directChatPhoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'Outfit',
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "Enter phone number...",
                                    hintStyle: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.4),
                                      fontSize: 13,
                                      fontWeight: FontWeight.normal,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.midnightBlue,
                          elevation: 0,
                          fixedSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onPressed: () {
                          final number = _directChatPhoneCtrl.text.trim();
                          if (number.isEmpty) {
                            AppSnackBar.warning(context, 'Please enter a phone number.');
                            return;
                          }
                          
                          // Normalize typed phone number to compare
                          final cleanTyped = number.replaceAll(RegExp(r'[^\d+]'), '').trim();
                          
                          // Check if any registered user matches this phone number
                          final matchedUser = _contacts.firstWhere(
                            (c) {
                              final cPhone = c['phone']?.toString().replaceAll(RegExp(r'[^\d+]'), '').trim() ?? '';
                              return cPhone.isNotEmpty && cPhone == cleanTyped;
                            },
                            orElse: () => {},
                          );

                          if (matchedUser.isNotEmpty) {
                            _startNewChat(matchedUser);
                          } else {
                            final uuid = ChatService.instance.deterministicUuidFromPhone(cleanTyped);
                            final newDirect = {
                              "id": uuid,
                              "name": "Technician ($number)",
                              "phone": number,
                              "online": false,
                              "role": "Clinical Technician",
                            };
                            _startNewChat(newDirect);
                          }
                          _directChatPhoneCtrl.clear();
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.send_rounded, size: 14, color: AppTheme.midnightBlue),
                            SizedBox(width: 6),
                            Text(
                              "Chat",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          fixedSize: const Size(46, 46),
                          elevation: 0,
                        ),
                        tooltip: "Chat on WhatsApp",
                        icon: const Icon(Icons.chat_bubble_rounded, size: 20),
                        onPressed: () {
                          final number = _directChatPhoneCtrl.text.trim();
                          if (number.isEmpty) {
                            AppSnackBar.warning(context, 'Please enter a phone number.');
                            return;
                          }
                          _launchWhatsAppChat(number);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.05, end: 0);
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
        Column(
          children: [
            _buildDirectChatInputCard(),
            Expanded(
              child: _isLoadingConversations
                  ? const Center(child: CircularProgressIndicator())
                  : chats.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.forum_outlined,
                                  size: 64, color: AppTheme.neutral.withValues(alpha: 0.4)),
                              const SizedBox(height: 16),
                              const Text(
                                "No Active Conversations",
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ).animate().fadeIn(),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(top: 4, bottom: 88),
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
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (chat['phone'] != null && chat['phone'].toString().trim().isNotEmpty) ...[
                                    IconButton(
                                      icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366), size: 22),
                                      tooltip: "Chat on WhatsApp",
                                      onPressed: () => _launchWhatsAppChat(chat['phone']),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Column(
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
            ),
          ],
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
    final query = _searchCtrl.text.trim().toLowerCase();
    final calls = query.isEmpty
        ? _calls
        : _calls.where((call) {
            return call['name'].toString().toLowerCase().contains(query) ||
                (call['status'] ?? '').toString().toLowerCase().contains(query) ||
                (call['phone'] ?? '').toString().toLowerCase().contains(query);
          }).toList();

    return Stack(
      children: [
        if (calls.isEmpty)
          Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Icon(Icons.call_rounded,
                    size: 64, color: AppTheme.neutral.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Text(query.isEmpty ? "No Recent Calls" : "No matching calls found",
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500))
              ]).animate().fadeIn())
        else
          ListView.separated(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: calls.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 80, color: AppTheme.divider),
            itemBuilder: (ctx, i) {
              final call = calls[i];
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
                  tooltip: 'Place call',
                  icon: const Icon(
                    Icons.call_rounded,
                    color: AppTheme.secondary,
                  ),
                  onPressed: () => _placePhoneCall(call),
                ),
                onTap: () => _placePhoneCall(call),
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
      _generatedMeetLink = ChatService.instance.generateMeetUrl();
    });
  }

  Widget _buildMeetingsList() {
    final query = _searchCtrl.text.trim().toLowerCase();
    final meetings = query.isEmpty
        ? _meetings
        : _meetings.where((m) {
            return m['topic'].toString().toLowerCase().contains(query) ||
                (m['host'] ?? '').toString().toLowerCase().contains(query);
          }).toList();

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildMeetGeneratorCard(),
            const SizedBox(height: 24),
            _buildLiveMeetingCard(),
            const SizedBox(height: 18),
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
            if (meetings.isEmpty)
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
                    Text(
                      query.isEmpty ? "No Upcoming Consultations" : "No matching consultations found",
                      style: const TextStyle(
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
              ...meetings.map((m) => _buildMeetingCard(m)),
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
                  final sentToGoogleChat =
                      await GoogleChatService.instance.sendMeetingCard(
                    topic: "Instant Technical Consultation Bridge",
                    time: "Started Now",
                    host: "Clinical Coordinator",
                    joinUrl: joinUrl,
                  );

                  if (!mounted) return;
                  final msg = sentToGoogleChat
                      ? 'Instant meeting started and sent to Google Chat.'
                      : 'Instant meeting started. Google Chat is not configured.';
                  AppSnackBar.success(context, msg);
                  _joinSimulatedMeet({
                    "topic": "Instant Technical Consultation Bridge",
                    "time": "Started now",
                    "host": "Clinical Coordinator",
                    "join_url": joinUrl,
                    "status": "live",
                    "participants": 4,
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMeetingCard(Map<String, dynamic> m) {
    final isLive = m['status'] == 'live' || m['time'] == 'Happening now';
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
                  Text(
                      "${isLive ? 'Live' : 'Scheduled'}: ${m['time']}  -  Host: ${m['host'] ?? 'Clinical Coordinator'}",
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontFamily: 'Outfit')),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isLive ? AppTheme.error : AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: () => _joinSimulatedMeet(m),
              child: Text(isLive ? "Join Live" : "Join"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveMeetingCard() {
    final liveMeetings = _meetings.cast<Map<String, dynamic>>().where(
          (meeting) =>
              meeting['status'] == 'live' ||
              meeting['time']?.toString() == 'Happening now',
        ).toList();

    if (liveMeetings.isEmpty) return const SizedBox.shrink();

    final liveMeeting = liveMeetings.first;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.error.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: AppTheme.error, size: 8),
                    SizedBox(width: 6),
                    Text(
                      "LIVE NOW",
                      style: TextStyle(
                        color: AppTheme.error,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(Icons.graphic_eq_rounded,
                  color: AppTheme.secondary, size: 18),
              const SizedBox(width: 6),
              const Text(
                "Notes detector active",
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            liveMeeting['topic']?.toString() ?? 'Clinical Consultation',
            style: const TextStyle(
              color: AppTheme.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Hosted by ${liveMeeting['host'] ?? 'Clinical Coordinator'} - ${liveMeeting['participants'] ?? 5} participants - Google Meet simulation",
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Clipboard.setData(ClipboardData(
                      text: liveMeeting['join_url']?.toString() ??
                          'https://meet.google.com/pulse-demo-live')),
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: const Text("Copy Meet Link"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _joinSimulatedMeet(liveMeeting),
                  icon: const Icon(Icons.video_call_rounded, size: 18),
                  label: const Text("Join Meeting"),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0);
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
                                AppSnackBar.success(context, "Meet link copied to clipboard!");
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
                              onPressed: () => _joinSimulatedMeet({
                                "topic": "Instant HD Consultation",
                                "time": "Started now",
                                "host": "You",
                                "join_url": _generatedMeetLink,
                                "status": "live",
                                "participants": 3,
                              }),
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
