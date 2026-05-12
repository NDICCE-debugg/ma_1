import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/services/sound_service.dart';
import 'package:ma_1/utils/animation_helper.dart';
import 'package:ma_1/screens/dashboard_view.dart';
import 'package:ma_1/screens/analytics_view.dart';
import 'package:ma_1/screens/collaboration_view.dart';
import 'package:ma_1/screens/ai_assistant_view.dart';
import 'package:ma_1/screens/hospital_map_view.dart';
import 'package:ma_1/services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final List<Widget> _pages = [const DashboardView(), const HospitalMapView(), const AnalyticsView(), const CollaborationView(), const AIAssistantView()];
  final List<String> _titles = ["SYSTEM OVERVIEW", "DIGITAL TWIN", "DATA METRICS", "COMMLINK", "AI ASSISTANT"];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.requestPermission(context);
      NotificationService.checkInventoryAlerts();
    });
  }

  void _onNavTapped(int index) {
    if (_currentIndex != index) {
      SoundService.instance.playTabSwitch();
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text(_titles[_currentIndex]).animate(key: ValueKey(_currentIndex)).shimmer(duration: 400.ms, color: Colors.white).shakeX(hz: 4, amount: 2),
        actions: [
          const Icon(Icons.wifi_tethering, color: AppTheme.accent).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.3, end: 1.0, duration: 1.seconds),
          const SizedBox(width: 20),
        ],
      ),
      body: ScanlineWrapper(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(animation), child: child)),
          child: KeyedSubtree(key: ValueKey(_currentIndex), child: _pages[_currentIndex]),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.bgLight,
          border: const Border(top: BorderSide(color: AppTheme.primary, width: 1)),
          boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.grid_view),
              _buildNavItem(1, Icons.map_outlined),
              _buildNavItem(2, Icons.analytics_outlined),
              _buildNavItem(3, Icons.radar),
              _buildNavItem(4, Icons.memory),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon) {
    bool isSelected = _currentIndex == index;
    Widget navIcon = GestureDetector(
      onTap: () => _onNavTapped(index),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? AppTheme.primary.withOpacity(0.2) : Colors.transparent,
          border: Border.all(color: isSelected ? AppTheme.primary : Colors.transparent, width: 1.5),
          boxShadow: isSelected ? [BoxShadow(color: AppTheme.primary.withOpacity(0.5), blurRadius: 12)] : null,
        ),
        child: Icon(icon, color: isSelected ? AppTheme.primary : AppTheme.textGrey, size: 24)
            .animate(target: isSelected ? 1 : 0)
            .scale(end: const Offset(1.2, 1.2), duration: 200.ms)
            .tint(color: Colors.white, end: 0.8),
      ),
    );

    // Apply the pulsing red alert dot over the analytics tab if stock is critical
    if (index == 2) {
      return ValueListenableBuilder<bool>(
        valueListenable: NotificationService.hasCriticalAlerts,
        builder: (context, hasCritical, child) {
          if (hasCritical) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                navIcon,
                Positioned(
                  right: 0, top: 0,
                  child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle))
                      .animate(onPlay: (c) => c.repeat(reverse: true)).fade(),
                ),
              ],
            );
          }
          return navIcon;
        },
      );
    }

    return navIcon;
  }
}