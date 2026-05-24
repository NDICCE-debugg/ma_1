import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ma_1/providers/theme_provider.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/services/gemini_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const _SettingsHeader(),
          const SizedBox(height: 18),
          _SettingsSection(
            title: 'Workspace',
            description:
                'Control the way the maintenance system behaves for you.',
            children: [
              SwitchListTile(
                value: themeProvider.isDarkMode,
                onChanged: (_) => themeProvider.toggleTheme(),
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Dark mode'),
                subtitle: const Text(
                    'Use a high-contrast interface for low-light work areas.'),
              ),
              const Divider(),
              const _SettingsTile(
                icon: Icons.notifications_active_outlined,
                title: 'Critical alerts',
                subtitle:
                    'Push alerts for overdue PMs, offline equipment, and high-risk faults.',
                trailing: _ValuePill('Enabled'),
              ),
              const _SettingsTile(
                icon: Icons.cloud_sync_outlined,
                title: 'Offline sync',
                subtitle:
                    'Keep local maintenance logs queued when the network is unstable.',
                trailing: _ValuePill('Ready'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _SettingsSection(
            title: 'Security & Privacy',
            description:
                'Safety controls for hospital data and technician activity.',
            children: [
              _SettingsTile(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Role permissions',
                subtitle:
                    'Technician access, approval rights, and asset editing privileges.',
                trailing: Icon(Icons.chevron_right_rounded),
              ),
              Divider(),
              _SettingsTile(
                icon: Icons.lock_outline_rounded,
                title: 'Session protection',
                subtitle:
                    'Password, session timeout, and device trust controls.',
                trailing: Icon(Icons.chevron_right_rounded),
              ),
              Divider(),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Clinical data policy',
                subtitle:
                    'Review privacy, retention, and audit trail expectations.',
                trailing: Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _SettingsSection(
            title: 'Support',
            description: 'Help resources and product information.',
            children: [
              _SettingsTile(
                icon: Icons.support_agent_rounded,
                title: 'Diagnostic support',
                subtitle: 'Contact the liaison desk or open a support request.',
                trailing: Icon(Icons.chevron_right_rounded),
              ),
              Divider(),
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'About Pulse',
                subtitle: 'Version, project details, and system information.',
                trailing: _ValuePill('v1.0.0'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) => const SettingsScreen();
}

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => const SettingsScreen();
}

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context) => const SettingsScreen();
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) => const SettingsScreen();
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Help Center')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: const [
          _SettingsHeader(
            title: 'Help Center',
            description:
                'Fast answers for equipment workflows, AI assistance, and clinical engineering support.',
          ),
          SizedBox(height: 18),
          _SettingsSection(
            title: 'Frequently Asked Questions',
            children: [
              _FaqTile(
                question: 'How do I add a new asset?',
                answer:
                    'Open Asset Control, use the add action, then complete the equipment identity and maintenance fields.',
              ),
              _FaqTile(
                question: 'How do I use AI safely?',
                answer:
                    'Use AI for technician decision support. Always confirm against manufacturer manuals and hospital SOPs.',
              ),
              _FaqTile(
                question: 'Can I work offline?',
                answer:
                    'Yes. Local logs queue offline and sync when connectivity returns.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => const SettingsScreen();
}

class _SettingsHeader extends StatelessWidget {
  final String title;
  final String description;

  const _SettingsHeader({
    this.title = 'System Settings',
    this.description = 'Configure your clinical engineering workspace.',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryDark, AppTheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondary.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.settings_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Outfit',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final String? description;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    this.description,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0A1518) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF24353A) : const Color(0xFFE8EEF1);
    final textPrimaryColor = isDark ? Colors.white : AppTheme.textPrimary;
    final textSecondaryColor = isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary;

    return Material(
      type: MaterialType.card,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorder, width: 1.2),
      ),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: textPrimaryColor,
                fontFamily: 'Outfit',
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(
                description!,
                style: TextStyle(
                  color: textSecondaryColor,
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.secondary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.1)),
        ),
        child: Icon(icon, color: AppTheme.secondary, size: 19),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        question,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(answer),
        ),
      ],
    );
  }
}

class _ValuePill extends StatelessWidget {
  final String label;

  const _ValuePill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.muted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.secondary,
          fontFamily: 'Outfit',
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _GeminiApiKeySection extends StatefulWidget {
  const _GeminiApiKeySection();

  @override
  State<_GeminiApiKeySection> createState() => _GeminiApiKeySectionState();
}

class _GeminiApiKeySectionState extends State<_GeminiApiKeySection> {
  final _keyController = TextEditingController();
  bool _obscureKey = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('custom_gemini_api_key') ?? '';
    if (mounted) {
      setState(() {
        _keyController.text = key;
      });
    }
  }

  Future<void> _saveKey() async {
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    final newKey = _keyController.text.trim();
    if (newKey.isNotEmpty) {
      await prefs.setString('custom_gemini_api_key', newKey);
    } else {
      await prefs.remove('custom_gemini_api_key');
    }
    GeminiService.instance.resetModel();
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.success,
          content: Text(
            newKey.isNotEmpty
                ? 'Gemini API key updated successfully. Models re-initialised.'
                : 'Custom API key cleared. Using default fallback.',
            style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: 'AI Diagnostics & API Configuration',
      description: 'Configure custom Google Gemini API access for real-time telemetry diagnostics.',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _keyController,
                obscureText: _obscureKey,
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Enter your Gemini API key (AIzaSy...)',
                  prefixIcon: const Icon(Icons.key_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_keyController.text.isNotEmpty) ...[
                    TextButton(
                      onPressed: () {
                        _keyController.clear();
                        _saveKey();
                      },
                      child: const Text('Clear Key'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _saveKey,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Save Key'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

