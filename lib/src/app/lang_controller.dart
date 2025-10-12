import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LangController extends ChangeNotifier {
  static const _key = 'app_locale'; // e.g., 'en', 'ko', 'es'
  Locale? _locale; // null = System Default
  Locale? get locale => _locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    _locale = (code == null || code.isEmpty) ? null : Locale(code);
    notifyListeners(); // 앱 시작 시 반영
  }

  Future<void> setLocale(Locale? l) async {
    if (_locale == l) return;
    _locale = l;
    final prefs = await SharedPreferences.getInstance();
    if (l == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, l.languageCode);
    }
    notifyListeners();
  }
}
