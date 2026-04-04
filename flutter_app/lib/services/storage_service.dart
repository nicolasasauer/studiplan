import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/study_plan.dart';

class StorageService {
  static const _kPlan = 'sp_plan';
  static const _kUser = 'sp_user';
  static const _kToken = 'sp_token';
  static const _kBaseUrl = 'sp_base_url';

  Future<void> savePlan(StudyPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPlan, jsonEncode(plan.toJson()));
  }

  Future<StudyPlan?> loadPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPlan);
    if (raw == null) return null;
    try {
      return StudyPlan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(String username, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUser, username);
    await prefs.setString(_kToken, token);
  }

  Future<Map<String, String>?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString(_kUser);
    final token = prefs.getString(_kToken);
    if (user == null || token == null) return null;
    return {'username': user, 'token': token};
  }

  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUser);
    await prefs.remove(_kToken);
  }

  Future<void> clearPlan() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPlan);
  }

  Future<void> saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, url);
  }

  Future<String> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kBaseUrl) ?? '';
  }

  static const _kLocalMode = 'sp_local_mode';

  Future<void> saveLocalMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLocalMode, enabled);
  }

  Future<bool> loadLocalMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kLocalMode) ?? false;
  }
}
