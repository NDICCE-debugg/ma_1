import 'package:flutter/material.dart';
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
  
  // Dummy participants for grid preview
  final List<String> _participants = ["You", "Sarah Jenkins", "Marcus Chen", "Dr. Alistair"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Text(widget.meetingTopic, style: const TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.group, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.chat, color: Colors.white), onPressed: () => setState(() => _isChatOpen = !_isChatOpen)),
        ],
      ),
      body: Stack(
        children: [
          // MAIN GRID
          Padding(
            padding: EdgeInsets.only(right: _isChatOpen ? MediaQuery.of(context).size.width * 0.3 : 0),
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _participants.length > 2 ? 2 : 1,
                crossAxisSpacing: 10, mainAxisSpacing: 10,
                childAspectRatio: _participants.length > 2 ? 0.8 : 1.5,
              ),
              itemCount: _participants.length,
              itemBuilder: (ctx, i) {
                bool isActiveSpeaker = i == 1; // Simulate active speaker
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isActiveSpeaker ? AppTheme.primary : Colors.transparent, width: 3),
                  ),
                  child: Stack(
                    children: [
                      Center(child: CircleAvatar(radius: 30, backgroundColor: Colors.white10, child: Text(_participants[i].substring(0, 1), style: const TextStyle(color: Colors.white, fontSize: 24)))),
                      Positioned(
                        bottom: 10, left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(5)),
                          child: Text(_participants[i], style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ),
                      Positioned(
                        top: 10, right: 10,
                        child: Icon(i == 2 ? Icons.mic_off : Icons.mic, color: i == 2 ? Colors.red : Colors.white, size: 16),
                      )
                    ],
                  ),
                );
              },
            ),
          ),

          // SIDE CHAT PANEL
          if (_isChatOpen)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.3,
                color: AppTheme.bgLight,
                child: Column(
                  children: [
                    const Padding(padding: EdgeInsets.all(15), child: Text("Meeting Chat", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    const Divider(color: Colors.white10, height: 1),
                    Expanded(child: ListView()), // Chat messages
                    Container(
                      padding: const EdgeInsets.all(10),
                      color: AppTheme.bgDark,
                      child: TextField(style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(hintText: "Send message...", hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none))),
                    )
                  ],
                ),
              ),
            ),

          // BOTTOM CONTROL BAR
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              color: Colors.black87,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlBtn(Icons.present_to_all, "Share"),
                  _buildControlBtn(Icons.back_hand, "Raise"),
                  _buildControlBtn(_isCameraOn ? Icons.videocam : Icons.videocam_off, "Camera", onTap: () => setState(() => _isCameraOn = !_isCameraOn)),
                  _buildControlBtn(_isMuted ? Icons.mic_off : Icons.mic, "Mic", onTap: () => setState(() => _isMuted = !_isMuted)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(25)), child: const Text("Leave", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildControlBtn(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}