import 'package:flutter/material.dart';
import 'package:ma_1/theme/app_theme.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final TextEditingController _nameController = TextEditingController(text: "Tadiwanashe M.");
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.primary,
                    child: Text("TM", style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
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
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 16),
            const TextField(
              enabled: false,
              decoration: InputDecoration(labelText: "Email (Non-editable)", prefixIcon: Icon(Icons.email_outlined)),
            ),
            const SizedBox(height: 16),
            const TextField(
              enabled: false,
              decoration: InputDecoration(labelText: "Registration Number", prefixIcon: Icon(Icons.badge_outlined)),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Change Password", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 16),
            const TextField(obscureText: true, decoration: InputDecoration(labelText: "Current Password")),
            const SizedBox(height: 12),
            const TextField(obscureText: true, decoration: InputDecoration(labelText: "New Password")),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text("Save All Changes"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}