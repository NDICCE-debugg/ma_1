import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/widgets/bioassist_drawer.dart';
import 'package:ma_1/services/notification_service.dart';
import 'package:ma_1/services/sync_service.dart';

// Import your views - Ensure these file names match your project
import 'package:ma_1/screens/dashboard_view.dart';
import 'package:ma_1/screens/collaboration_view.dart';
import 'package:ma_1/screens/ai_assistant_view.dart';
import 'package:ma_1/screens/analytics_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  Timer? _syncTimer;

  // The list of clinical modules
  final List<Widget> _views = [
    const DashboardView(),
    const AnalyticsView(),
    const AIAssistantView(),
    const CollaborationView(),
  ];

  final List<String> _titles = [
    "Equipment Overview",
    "Inventory & Assets",
    "AI BioMed Assistant",
    "Technician Comms",
  ];

  @override
  void initState() {
    super.initState();
    // Requesting system permissions for clinical alerts on boot
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.requestPermission(context);
    });

    // Start background sync timer
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      SyncService.instance.syncData();
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      
      // --- THE SIDEBAR FIX ---
      // This enables the hamburger menu and the slide-out profile
      drawer: const BioAssistDrawer(),

      appBar: AppBar(
        centerTitle: true,
        title: Column(
          children: [
            Text(
              _titles[_selectedIndex],
              style: const TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                color: AppTheme.textPrimary
              ),
            ),
            if (_selectedIndex == 0)
              const Text(
                "Harare Central Hospital", // Contextual location
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primary),
            onPressed: () {
              // Trigger your mobile_scanner logic here
            },
          ),
          const SizedBox(width: 8),
        ],
      ),

      // IndexedStack keeps the state of your views alive when switching tabs
      body: IndexedStack(
        index: _selectedIndex,
        children: _views,
      ),

      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppTheme.border, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).cardTheme.color,
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: AppTheme.textSecondary,
          selectedLabelStyle: const TextStyle(
            fontSize: 12, 
            fontWeight: FontWeight.bold, 
            fontFamily: 'Inter'
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12, 
            fontFamily: 'Inter'
          ),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2),
              label: 'Assets',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.psychology_outlined),
              activeIcon: Icon(Icons.psychology),
              label: 'AI Help',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.chat_bubble_outline),
                  // Clinical Alert Badge (Red Dot)
                  ValueListenableBuilder<bool>(
                    valueListenable: NotificationService.hasCriticalAlerts,
                    builder: (context, hasAlerts, child) {
                      return hasAlerts 
                        ? Positioned(
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                color: AppTheme.error,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 8,
                                minHeight: 8,
                              ),
                            ),
                          )
                        : const SizedBox.shrink();
                    },
                  ),
                ],
              ),
              activeIcon: const Icon(Icons.chat_bubble),
              label: 'Comms',
            ),
          ],
        ),
      ),
    );
  }
}