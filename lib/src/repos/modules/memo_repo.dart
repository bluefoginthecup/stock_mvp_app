import 'package:shared_preferences/shared_preferences.dart';

class MemoRepo {
  static const _key = 'dashboard_memo';

  Future<String> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? '';
  }

  Future<void> save(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, text);
  }
}