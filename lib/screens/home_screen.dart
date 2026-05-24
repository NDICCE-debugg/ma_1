import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ma_1/screens/ai_assistant_view.dart';
import 'package:ma_1/screens/analytics_view.dart';
import 'package:ma_1/screens/collaboration_view.dart';
import 'package:ma_1/screens/dashboard_view.dart';
import 'package:ma_1/screens/login_screen.dart';
import 'package:ma_1/screens/profile_edit_screen.dart';
import 'package:ma_1/screens/settings_screens.dart';
import 'package:ma_1/services/auth_service.dart';
import 'package:ma_1/services/notification_service.dart';
import 'package:ma_1/services/sync_service.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/widgets/pulse_logo.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  Timer? _syncTimer;

  final List<Widget> _views = const [
    DashboardView(),
    AnalyticsView(),
    AIAssistantView(),
    CollaborationView(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.requestPermission(context);
    });
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
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
    final selectedIndex = _selectedIndex.clamp(0, _views.length - 1);
    final isWide = MediaQuery.sizeOf(context).width >= 920;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildTopBar(selectedIndex),
      body: Row(
        children: [
          if (isWide) _buildDesktopRail(selectedIndex),
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: AppTheme.divider)),
              ),
              child: IndexedStack(index: selectedIndex, children: _views),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide ? null : _buildMobileNav(selectedIndex),
    );
  }

  PreferredSizeWidget _buildTopBar(int selectedIndex) {
    return AppBar(
      toolbarHeight: 72,
      centerTitle: false,
      backgroundColor: AppTheme.surface.withValues(alpha: 0.97),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const Border(
        bottom: BorderSide(color: AppTheme.divider),
      ),
      titleSpacing: 0,
      leadingWidth: 58,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: IconButton(
          tooltip: 'Account menu',
          icon: const Icon(Icons.menu_rounded),
          onPressed: _showAccountMenu,
        ),
      ),
      title: Row(
        children: [
          const PulseLogo(size: 38, borderRadius: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _titleFor(selectedIndex),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppTheme.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _subtitleFor(selectedIndex),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        ValueListenableBuilder<bool>(
          valueListenable: NotificationService.hasCriticalAlerts,
          builder: (context, hasAlerts, child) {
            return Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: hasAlerts
                    ? AppTheme.error.withValues(alpha: 0.08)
                    : AppTheme.muted,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: hasAlerts
                      ? AppTheme.error.withValues(alpha: 0.18)
                      : AppTheme.divider,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasAlerts
                        ? Icons.report_problem_rounded
                        : Icons.cloud_done_rounded,
                    size: 15,
                    color: hasAlerts ? AppTheme.error : AppTheme.secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hasAlerts ? 'Critical' : 'Synced',
                    style: TextStyle(
                      color: hasAlerts ? AppTheme.error : AppTheme.secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDesktopRail(int selectedIndex) {
    return Builder(
      builder: (context) {
        return Container(
          width: 244,
          color: AppTheme.surface,
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    PulseLogo(size: 34, borderRadius: 9),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pulse',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontFamily: 'Outfit',
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Equipment OS',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontFamily: 'Outfit',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'Workspace',
                  style: TextStyle(
                    color: AppTheme.mutedForeground,
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: _navDestinations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = _navDestinations[index];
                    return _DesktopNavItem(
                      item: item,
                      selected: selectedIndex == index,
                      onTap: () => setState(() => _selectedIndex = index),
                    );
                  },
                ),
              ),
              const Divider(height: 18),
              _DesktopNavAction(
                icon: Icons.tune_rounded,
                label: 'Settings',
                onTap: () => _openScreen(const SettingsScreen()),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.muted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cloud_done_rounded,
                        color: AppTheme.secondary, size: 17),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Offline sync ready',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileNav(int selectedIndex) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.divider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              children: List.generate(_navDestinations.length, (index) {
                final item = _navDestinations[index];
                return Expanded(
                  child: _MobileNavItem(
                    item: item,
                    selected: selectedIndex == index,
                    onTap: () => setState(() => _selectedIndex = index),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  void _openScreen(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _showAccountMenu() async {
    final user = AuthService.instance.currentUser;
    final metadata = user?.userMetadata ?? {};
    final name = metadata['name'] as String? ?? 'Biomedical Technician';
    final email = user?.email ?? 'technician@hospital.gov';
    final reg = metadata['reg_number'] as String? ?? 'REG: 2026-HIT-04';
    final initials = _initials(name);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Outfit',
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontFamily: 'Outfit',
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontFamily: 'Outfit',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.muted,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.badge_outlined,
                            color: AppTheme.secondary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            reg,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontFamily: 'Outfit',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const _MiniStatus(label: 'Active'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _AccountMenuTile(
                    icon: Icons.account_circle_outlined,
                    title: 'Professional profile',
                    subtitle: 'Credentials, role, skills, and contact details',
                    onTap: () {
                      Navigator.pop(dialogContext);
                      _openScreen(const ProfileEditScreen());
                    },
                  ),
                  _AccountMenuTile(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    subtitle: 'Appearance, notifications, privacy, and support',
                    onTap: () {
                      Navigator.pop(dialogContext);
                      _openScreen(const SettingsScreen());
                    },
                  ),
                  _AccountMenuTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Help and support',
                    subtitle: 'Guides, safety notes, and liaison channels',
                    onTap: () {
                      Navigator.pop(dialogContext);
                      _openScreen(const HelpScreen());
                    },
                  ),
                  const Divider(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: const BorderSide(color: AppTheme.error),
                      ),
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        await AuthService.instance.signOut();
                        if (!mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Sign out'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final value = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return value.isEmpty ? 'BT' : value;
  }

  List<_NavItem> get _navDestinations => const [
        _NavItem(
          label: 'Dashboard',
          description: 'Fleet overview',
          icon: Icons.space_dashboard_outlined,
          activeIcon: Icons.space_dashboard_rounded,
        ),
        _NavItem(
          label: 'Assets',
          description: 'Parts and equipment',
          icon: Icons.precision_manufacturing_outlined,
          activeIcon: Icons.precision_manufacturing_rounded,
        ),
        _NavItem(
          label: 'AI Help',
          description: 'Diagnostic support',
          icon: Icons.auto_awesome_outlined,
          activeIcon: Icons.auto_awesome_rounded,
        ),
        _NavItem(
          label: 'Comms',
          description: 'Team coordination',
          icon: Icons.forum_outlined,
          activeIcon: Icons.forum_rounded,
        ),
      ];

  String _titleFor(int index) {
    return switch (index) {
      0 => 'Ops Dashboard',
      1 => 'Asset Control',
      2 => 'AI Help Desk',
      3 => 'Clinical Comms',
      _ => 'Pulse',
    };
  }

  String _subtitleFor(int index) {
    return switch (index) {
      0 => 'Maintenance signals, risk queue, and fleet readiness',
      1 => 'Equipment records, inventory, and service controls',
      2 => 'Technician prompts, manuals, images, and audio context',
      3 => 'Chats, calls, meetings, and field coordination',
      _ => 'Clinical engineering workspace',
    };
  }
}

class _NavItem {
  final String label;
  final String description;
  final IconData icon;
  final IconData activeIcon;

  const _NavItem({
    required this.label,
    required this.description,
    required this.icon,
    required this.activeIcon,
  });
}

class _DesktopNavItem extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _DesktopNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.description,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppTheme.primary : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.12)
                      : AppTheme.muted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppTheme.divider,
                  ),
                ),
                child: Icon(
                  selected ? item.activeIcon : item.icon,
                  size: 19,
                  color: selected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : AppTheme.textPrimary,
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.68)
                            : AppTheme.textSecondary,
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopNavAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DesktopNavAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.textSecondary, size: 19),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontFamily: 'Outfit',
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _MobileNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.description,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOut,
          height: 58,
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? item.activeIcon : item.icon,
                size: 21,
                color: selected ? Colors.white : AppTheme.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSecondary,
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStatus extends StatelessWidget {
  final String label;

  const _MiniStatus({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.success,
          fontFamily: 'Outfit',
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AccountMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AccountMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.muted,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Icon(icon, color: AppTheme.secondary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
