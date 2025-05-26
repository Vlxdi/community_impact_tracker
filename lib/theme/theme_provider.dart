import 'package:community_impact_tracker/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  AppThemeMode _appThemeMode = AppThemeMode.light;

  ThemeProvider() {
    _loadThemeFromPreferences();
  }

  AppThemeMode get appThemeMode => _appThemeMode;

  ThemeData get themeData {
    switch (_appThemeMode) {
      case AppThemeMode.dark:
        return darkMode;
      case AppThemeMode.gradient:
        return lightMode; // Use lightMode as base for gradient
      case AppThemeMode.light:
      default:
        return lightMode;
    }
  }

  void toggleTheme() {
    if (_appThemeMode == AppThemeMode.light) {
      appThemeMode = AppThemeMode.dark;
    } else if (_appThemeMode == AppThemeMode.dark) {
      appThemeMode = AppThemeMode.light;
    }
    // Do not toggle to gradient here
  }

  set appThemeMode(AppThemeMode mode) {
    _appThemeMode = mode;
    _saveThemeToPreferences(mode);
    notifyListeners();
  }

  Future<void> _loadThemeFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('appThemeMode') ?? 0;
    _appThemeMode = AppThemeMode.values[themeIndex];
    notifyListeners();
  }

  Future<void> _saveThemeToPreferences(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('appThemeMode', mode.index);
  }
}
