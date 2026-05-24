import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ma_1/services/auth_service.dart';
import 'package:ma_1/theme/app_theme.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _regController;
  late final TextEditingController _roleController;
  late final TextEditingController _departmentController;
  late final TextEditingController _phoneController;
  late final TextEditingController _licenseController;
  late final TextEditingController _bioController;
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;

  bool _isLoading = false;
  final Set<String> _skills = {
    'Ventilators',
    'Anaesthesia',
    'Oxygen plant',
    'Calibration',
  };

  @override
  void initState() {
    super.initState();
    final user = AuthService.instance.currentUser;
    final metadata = user?.userMetadata ?? {};

    _nameController = TextEditingController(
        text: metadata['name'] as String? ?? 'Tadiwanashe M.');
    _emailController =
        TextEditingController(text: user?.email ?? 'technician@hospital.gov');
    _regController = TextEditingController(
        text: metadata['reg_number'] as String? ?? 'REG: 2026-HIT-04');
    _roleController = TextEditingController(
        text: metadata['role_title'] as String? ?? 'Biomedical Technician');
    _departmentController = TextEditingController(
        text: metadata['department'] as String? ?? 'Clinical Engineering');
    _phoneController =
        TextEditingController(text: metadata['phone'] as String? ?? '');
    _licenseController = TextEditingController(
        text: metadata['license'] as String? ?? 'HIT-BME-2026');
    _bioController = TextEditingController(
        text: metadata['bio'] as String? ??
            'Responsible for preventive maintenance, urgent fault response, and clinical equipment readiness across critical care units.');
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _regController.dispose();
    _roleController.dispose();
    _departmentController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _bioController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return;

      final metadata = {
        'name': _nameController.text.trim(),
        'reg_number': _regController.text.trim(),
        'role_title': _roleController.text.trim(),
        'department': _departmentController.text.trim(),
        'phone': _phoneController.text.trim(),
        'license': _licenseController.text.trim(),
        'bio': _bioController.text.trim(),
        'skills': _skills.toList(),
      };

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: metadata),
      );

      try {
        await Supabase.instance.client.from('users').upsert({
          'id': user.id,
          'name': _nameController.text.trim(),
          'email': user.email,
          'reg_number': _regController.text.trim(),
          'role': 'technician',
          'online': true,
          'last_seen': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {}

      if (_newPasswordController.text.isNotEmpty) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: _newPasswordController.text),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Professional profile updated.')),
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.error,
          content: Text('Failed to update profile: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials(_nameController.text);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Professional Profile'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _saveChanges,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded, size: 17),
              label: const Text('Save'),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final content = [
            _buildProfileSummary(initials),
            _buildProfessionalDetails(),
            _buildSkillsAndAccess(),
            _buildSecurityCard(),
          ];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 340, child: content[0]),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          children: [
                            content[1],
                            const SizedBox(height: 18),
                            content[2],
                            const SizedBox(height: 18),
                            content[3],
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      for (final item in content) ...[
                        item,
                        if (item != content.last) const SizedBox(height: 18),
                      ],
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildProfileSummary(String initials) {
    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameController.text,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _roleController.text,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _profileMetric('Work orders closed', '128', Icons.task_alt_rounded),
          _profileMetric('Avg response time', '18m', Icons.bolt_rounded),
          _profileMetric('Compliance score', '96%', Icons.verified_rounded),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusBadge(label: 'Active', color: AppTheme.success),
              _StatusBadge(label: 'On-call ready', color: AppTheme.secondary),
              _StatusBadge(label: 'Verified', color: AppTheme.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalDetails() {
    return _ProfileCard(
      title: 'Professional Details',
      description:
          'Profile information used across chats, service logs, and technician coordination.',
      child: Column(
        children: [
          _field(_nameController, 'Full name', Icons.account_circle_outlined),
          _field(
              _emailController, 'Email address', Icons.alternate_email_rounded,
              enabled: false),
          _field(_regController, 'Registration number', Icons.badge_outlined),
          _field(_roleController, 'Role title', Icons.engineering_outlined),
          _field(_departmentController, 'Department', Icons.apartment_rounded),
          _field(_phoneController, 'Phone / on-call line', Icons.call_rounded),
          _field(_licenseController, 'License / credential ID',
              Icons.workspace_premium_outlined),
          TextField(
            controller: _bioController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Professional summary',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsAndAccess() {
    const availableSkills = [
      'Ventilators',
      'Anaesthesia',
      'Oxygen plant',
      'Calibration',
      'Patient monitors',
      'Sterilisation',
      'Imaging',
      'Inventory control',
    ];

    return _ProfileCard(
      title: 'Skills & Access',
      description:
          'Specialties shown to colleagues when they escalate equipment faults.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableSkills.map((skill) {
              final selected = _skills.contains(skill);
              return FilterChip(
                label: Text(skill),
                selected: selected,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _skills.add(skill);
                    } else {
                      _skills.remove(skill);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 14),
          _accessRow('Can approve maintenance logs', true),
          _accessRow('Can manage spare parts inventory', true),
          _accessRow('Can edit hospital-wide assets', false),
        ],
      ),
    );
  }

  Widget _buildSecurityCard() {
    return _ProfileCard(
      title: 'Security',
      description: 'Update login credentials for this account.',
      child: Column(
        children: [
          _field(_currentPasswordController, 'Current password',
              Icons.lock_open_rounded,
              obscure: true),
          _field(_newPasswordController, 'New password', Icons.lock_rounded,
              obscure: true),
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Use a unique password for hospital maintenance systems.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Outfit',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool enabled = true,
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        enabled: enabled,
        obscureText: obscure,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  Widget _profileMetric(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.muted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.secondary, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Outfit')),
          ),
          Text(value,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Outfit')),
        ],
      ),
    );
  }

  Widget _accessRow(String label, bool enabled) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
            color: enabled ? AppTheme.success : AppTheme.textSecondary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Outfit')),
          ),
        ],
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? 'BT' : letters;
  }
}

class _ProfileCard extends StatelessWidget {
  final String? title;
  final String? description;
  final Widget child;

  const _ProfileCard({
    this.title,
    this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontFamily: 'Outfit',
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(
                  description!,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }
}
