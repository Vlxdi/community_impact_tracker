import 'package:community_impact_tracker/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeData _themeData = lightMode;

  ThemeProvider() {
    _loadThemeFromPreferences();
  }

  ThemeData get themeData => _themeData;

  set themeData(ThemeData themeData) {
    _themeData = themeData;
    _saveThemeToPreferences(themeData == darkMode);
    notifyListeners();
  }

  void toggleTheme() {
    themeData = _themeData == lightMode ? darkMode : lightMode;
  }

  Future<void> _loadThemeFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _themeData = isDarkMode ? darkMode : lightMode;
    notifyListeners();
  }

  Future<void> _saveThemeToPreferences(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }
}
