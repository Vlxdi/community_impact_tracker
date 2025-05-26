import 'package:community_impact_tracker/main_pages/settings/account_settings.dart';
import 'package:community_impact_tracker/outer_pages/login.dart';
import 'package:community_impact_tracker/theme/theme.dart';
import 'package:community_impact_tracker/widgets/q_warning.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:community_impact_tracker/theme/theme_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: const Text('Account'),
            subtitle: const Text('Manage your account settings'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () async {
              bool? accountUpdated = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AccountSettingsPage()),
              );
              if (accountUpdated == true) {
                Navigator.pop(context, true);
              }
            },
          ),
          SwitchListTile(
            title: const Text('Notifications'),
            subtitle: const Text('Enable notifications'),
            value: true,
            onChanged: (bool value) {
              // Handle notification toggle
            },
          ),
          QWarning(
            title: 'Experimental',
            subtitle:
                'This feature is currently under development and might not work as expected.',
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Use dark theme'),
                  value: themeProvider.appThemeMode == AppThemeMode.dark,
                  onChanged: themeProvider.appThemeMode == AppThemeMode.gradient
                      ? null
                      : (bool value) {
                          themeProvider.appThemeMode =
                              value ? AppThemeMode.dark : AppThemeMode.light;
                        },
                ),
                SwitchListTile(
                  title: const Text('Gradient Theme'),
                  subtitle: const Text('Animated blue gradient background'),
                  value: themeProvider.appThemeMode == AppThemeMode.gradient,
                  onChanged: (bool value) {
                    if (value) {
                      themeProvider.appThemeMode = AppThemeMode.gradient;
                    } else {
                      // Revert to light mode when turning off gradient
                      themeProvider.appThemeMode = AppThemeMode.light;
                    }
                  },
                ),
              ],
            ),
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
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
