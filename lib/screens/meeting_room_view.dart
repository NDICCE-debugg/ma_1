import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ma_1/theme/app_theme.dart';

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
  
  // Professional participant list
  final List<String> _participants = ["You", "Sarah Jenkins", "Marcus Chen", "Dr. Alistair"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background, // F4F6F9 Medical Light Grey-Blue
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.primary, size: 20), 
          onPressed: () => Navigator.pop(context)
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.meetingTopic, 
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            const Text("Clinical Consultation", 
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppTheme.border, height: 1.0),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline, color: AppTheme.primary), 
            onPressed: () {}
          ),
          IconButton(
            icon: Icon(_isChatOpen ? Icons.chat : Icons.chat_bubble_outline, color: AppTheme.primary), 
            onPressed: () => setState(() => _isChatOpen = !_isChatOpen)
          ),
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
                bool isActiveSpeaker = i == 1; // Simulate clinical focus
                return _buildVideoCard(_participants[i], isActiveSpeaker, i == 2);
              },
            ),
          ),

          // SIDE CHAT PANEL (Integrated Clinical Sidebar)
          if (_isChatOpen)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.35,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(left: BorderSide(color: AppTheme.border)),
                ),
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16), 
                      child: Text("Consultation Chat", 
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13))
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          _buildMiniChatBubble("Sarah", "I've uploaded the schematics."),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppTheme.background,
                        border: Border(top: BorderSide(color: AppTheme.border)),
                      ),
                      child: TextField(
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: "Message...",
                          hintStyle: const TextStyle(fontSize: 12),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20), 
                            borderSide: BorderSide.none
                          ),
                        ),
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
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))
                ],
                border: const Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlBtn(Icons.screen_share_outlined, "Share"),
                  _buildControlBtn(Icons.back_hand_outlined, "Raise"),
                  _buildControlBtn(
                    _isCameraOn ? Icons.videocam_outlined : Icons.videocam_off_outlined, 
                    "Camera", 
                    onTap: () => setState(() => _isCameraOn = !_isCameraOn),
                    isActive: _isCameraOn
                  ),
                  _buildControlBtn(
                    _isMuted ? Icons.mic_off_outlined : Icons.mic_none_outlined, 
                    "Mic", 
                    onTap: () => setState(() => _isMuted = !_isMuted),
                    isActive: !_isMuted
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Text("Leave", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppTheme.secondary : AppTheme.border, 
          width: isActive ? 2 : 1
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: CircleAvatar(
              radius: 32, 
              backgroundColor: AppTheme.background, 
              child: Text(name.substring(0, 1), 
                style: const TextStyle(color: AppTheme.primary, fontSize: 24, fontWeight: FontWeight.bold))
            )
          ),
          // Name Tag Pill
          Positioned(
            bottom: 12, left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6), 
                borderRadius: BorderRadius.circular(6)
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isMuted)
                    const Icon(Icons.mic_off, color: Colors.white, size: 12),
                  if (isMuted) const SizedBox(width: 4),
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          // Active Speaker Indicator
          if (isActive)
            Positioned(
              top: 12, right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.secondary, borderRadius: BorderRadius.circular(4)),
                child: const Text("SPEAKING", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildControlBtn(IconData icon, String label, {VoidCallback? onTap, bool isActive = true}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? AppTheme.primary : AppTheme.textSecondary, size: 24),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildMiniChatBubble(String sender, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sender, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8)),
            child: Text(text, style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}