import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/services/auth_service.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _regController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = AuthService.instance.currentUser;
    final name = user?.userMetadata?['name'] as String? ?? "Tadiwanashe M.";
    final email = user?.email ?? "tadiwa@bioassist.org";
    final reg = user?.userMetadata?['reg_number'] as String? ?? "REG: 2026-HIT-04";

    _nameController = TextEditingController(text: name);
    _emailController = TextEditingController(text: email);
    _regController = TextEditingController(text: reg);
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _regController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      final user = AuthService.instance.currentUser;
      if (user != null) {
        // Update user metadata in Supabase Auth
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(
            data: {
              'name': _nameController.text,
              'reg_number': _regController.text,
            },
          ),
        );
        
        // Upsert user profile record in public users table
        try {
          await Supabase.instance.client.from('users').upsert({
            'id': user.id,
            'name': _nameController.text,
            'email': user.email,
            'reg_number': _regController.text,
            'role': 'technician',
            'online': true,
          });
        } catch (_) {}

        if (_newPasswordController.text.isNotEmpty) {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(password: _newPasswordController.text),
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppTheme.success, 
              behavior: SnackBarBehavior.floating,
              content: Text("Profile and credentials updated successfully!", style: TextStyle(fontFamily: 'Outfit'))
            ),
          );
          _newPasswordController.clear();
          _currentPasswordController.clear();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.error, 
            behavior: SnackBarBehavior.floating,
            content: Text("Failed to update profile: $e", style: const TextStyle(fontFamily: 'Outfit'))
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final name = user?.userMetadata?['name'] as String? ?? _nameController.text;
    final initials = name.isNotEmpty ? name.substring(0, 2).toUpperCase() : "TM";

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Edit Profile"),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.primary,
                    child: Text(initials, style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: AppTheme.secondary,
                      radius: 18,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                        onPressed: () {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(fontFamily: 'Outfit'),
                      decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person_outline)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      enabled: false,
                      style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.textSecondary),
                      decoration: const InputDecoration(labelText: "Email (Non-editable)", prefixIcon: Icon(Icons.email_outlined)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _regController,
                      style: const TextStyle(fontFamily: 'Outfit'),
                      decoration: const InputDecoration(labelText: "Registration Number", prefixIcon: Icon(Icons.badge_outlined)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: AppTheme.divider),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Change Password", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Outfit', color: AppTheme.primary)),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    TextField(
                      controller: _currentPasswordController,
                      obscureText: true, 
                      style: const TextStyle(fontFamily: 'Outfit'),
                      decoration: const InputDecoration(labelText: "Current Password", prefixIcon: Icon(Icons.lock_open_outlined))
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: true, 
                      style: const TextStyle(fontFamily: 'Outfit'),
                      decoration: const InputDecoration(labelText: "New Password", prefixIcon: Icon(Icons.lock_outline))
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saveChanges,
                    child: const Text("Save All Changes", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}