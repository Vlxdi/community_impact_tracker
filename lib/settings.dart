import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart'; // Ensure this imports the correct login page

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: const Text('Account'),
            subtitle: const Text('Manage your account settings'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Add navigation to account settings
            },
          ),
          SwitchListTile(
            title: const Text('Notifications'),
            subtitle: const Text('Enable notifications'),
            value: true, // Change this to a stateful variable if needed
            onChanged: (bool value) {
              // Handle notification toggle
            },
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Use dark theme'),
            value: false, // Change this to a stateful variable if needed
            onChanged: (bool value) {
              // Handle dark mode toggle
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Privacy'),
            subtitle: const Text('Manage privacy settings'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Add navigation to privacy settings
            },
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & Support'),
            subtitle: const Text('Get help or send feedback'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Add navigation to help/support
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              // Navigate back to the login page
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => LoginPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
