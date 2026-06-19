import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  SettingsRepository(this._prefs);

  static const _geminiApiKeyKey = 'gemini_api_key';
  static const _applicantNameKey = 'applicant_name';
  static const _followUpDaysKey = 'follow_up_days';

  final SharedPreferences _prefs;

  String? get geminiApiKey => _prefs.getString(_geminiApiKeyKey);

  String get applicantName => _prefs.getString(_applicantNameKey) ?? '';

  int get followUpDays => _prefs.getInt(_followUpDaysKey) ?? 5;

  bool get hasGeminiApiKey => geminiApiKey != null && geminiApiKey!.trim().isNotEmpty;

  Future<void> saveGeminiApiKey(String? value) async {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _prefs.remove(_geminiApiKeyKey);
      return;
    }
    await _prefs.setString(_geminiApiKeyKey, trimmed);
  }

  Future<void> saveApplicantName(String value) async {
    await _prefs.setString(_applicantNameKey, value.trim());
  }

  Future<void> saveFollowUpDays(int days) async {
    await _prefs.setInt(_followUpDaysKey, days.clamp(1, 30));
  }
}
