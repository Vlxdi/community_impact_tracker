import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  _AccountSettingsPageState createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      _displayNameController.text = user.displayName ?? '';
      _emailController.text = user.email ?? '';
    }
  }

  Future<void> _updateProfile() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Update display name in FirebaseAuth
        await user.updateDisplayName(_displayNameController.text);

        // Update the display name in Firestore under 'users' collection
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'username': _displayNameController.text});

        // Reload user to refresh local data
        await user.reload();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );

        // Return true on successful update to trigger a refresh on profile page
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    }
  }

  Future<void> _changePassword() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Reauthenticate with the current password
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: _passwordController.text,
        );
        await user.reauthenticateWithCredential(cred);

        // Update to new password
        await user.updatePassword(_newPasswordController.text);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully!')),
        );
        _passwordController.clear();
        _newPasswordController.clear();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to change password: $e')),
      );
    }
  }

  @override
  void dispose() {
    // Dispose controllers to free up resources
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Display name field
            TextField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                hintText: 'Enter your display name',
              ),
            ),
            const SizedBox(height: 16),

            // Email field
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your email address',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // Update Profile button
            ElevatedButton(
              onPressed: _updateProfile,
              child: const Text('Update Profile'),
            ),

            const Divider(height: 32),

            // Change Password section
            Text(
              'Change Password',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Current password field
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Current Password',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),

            // New password field
            TextField(
              controller: _newPasswordController,
              decoration: const InputDecoration(
                labelText: 'New Password',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),

            // Change Password button
            ElevatedButton(
              onPressed: _changePassword,
              child: const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }
}
