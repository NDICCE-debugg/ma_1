import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ma_1/providers/theme_provider.dart';
import 'package:ma_1/theme/app_theme.dart';

// 1. APPEARANCE
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text("Appearance")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              title: const Text("Dark Mode", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Apply high-contrast dark medical interface"),
              value: themeProvider.isDarkMode,
              onChanged: (val) => themeProvider.toggleTheme(),
            ),
          ),
        ],
      ),
    );
  }
}

// 2. HELP & FAQ
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Help Center")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Frequently Asked Questions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildFaq("How do I add a new asset?", "Tap the '+' icon on the Assets dashboard and fill in the equipment details."),
          _buildFaq("How do I query the AI assistant?", "Navigate to the AI Assistant tab and use text or voice commands."),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: () {}, child: const Text("Open Full User Guide")),
        ],
      ),
    );
  }

  Widget _buildFaq(String q, String a) {
    return ExpansionTile(
      title: Text(q, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      children: [Padding(padding: const EdgeInsets.all(16), child: Text(a))],
    );
  }
}

// 3. ABOUT
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("About")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.health_and_safety, size: 80, color: AppTheme.primaryBlue),
              const SizedBox(height: 16),
              const Text("BioAssist", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Text("Version 1.0.0", style: TextStyle(color: Colors.grey)),
              const Spacer(),
              const Text(
                "Developed for biomedical technicians at public hospitals in Zimbabwe.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 40),
              const Text("HIT400 Capstone Project", style: TextStyle(fontWeight: FontWeight.bold)),
              const Text("Harare Institute of Technology"),
              const Text("2026"),
            ],
          ),
        ),
      ),
    );
  }
}

// Placeholders for other menu items
class NotificationSettingsScreen extends StatelessWidget { const NotificationSettingsScreen({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Notifications"))); }
class SafetyScreen extends StatelessWidget { const SafetyScreen({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Safety & Privacy"))); }
class SupportScreen extends StatelessWidget { const SupportScreen({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Support"))); }