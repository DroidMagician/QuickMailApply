import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/application_record.dart';

class ApplicationHistoryRepository {
  ApplicationHistoryRepository(this._prefs);

  static const _storageKey = 'application_history_v2';
  static const _maxRecords = 100;

  final SharedPreferences _prefs;
  final _uuid = const Uuid();

  List<ApplicationRecord> loadHistory() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return _migrateFromV1();

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => ApplicationRecord.fromJson(item as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
    } catch (_) {
      return [];
    }
  }

  List<ApplicationRecord> _migrateFromV1() {
    final raw = _prefs.getString('application_history_v1');
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return ApplicationRecord(
          id: map['id'] as String,
          recruiterEmail: map['recruiterEmail'] as String,
          profileId: map['profileId'] as String,
          profileName: map['profileName'] as String,
          subject: map['subject'] as String,
          appliedAt: DateTime.parse(map['appliedAt'] as String),
        );
      }).toList()
        ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> addRecord({
    required String recruiterEmail,
    required String profileId,
    required String profileName,
    required String subject,
    String? jobTitle,
    int followUpDays = 5,
    String? gmailMessageId,
    String? gmailThreadId,
    String? replyStatus,
  }) async {
    final record = ApplicationRecord(
      id: _uuid.v4(),
      recruiterEmail: recruiterEmail.trim(),
      profileId: profileId,
      profileName: profileName,
      subject: subject,
      appliedAt: DateTime.now(),
      jobTitle: jobTitle,
      followUpAt: DateTime.now().add(Duration(days: followUpDays)),
      gmailMessageId: gmailMessageId,
      gmailThreadId: gmailThreadId,
      replyStatus: replyStatus ?? (gmailThreadId != null ? 'sent' : 'none'),
    );

    final history = loadHistory();
    history.insert(0, record);

    if (history.length > _maxRecords) {
      history.removeRange(_maxRecords, history.length);
    }

    await _save(history);
  }

  Future<void> updateReplyStatus({
    required String recordId,
    required String replyStatus,
    String? snippet,
  }) async {
    final history = loadHistory();
    final index = history.indexWhere((r) => r.id == recordId);
    if (index == -1) return;

    history[index] = history[index].copyWith(
      replyStatus: replyStatus,
      lastReplySnippet: snippet,
      lastCheckedAt: DateTime.now(),
    );
    await _save(history);
  }

  Future<void> markFollowUpDone(String recordId) async {
    final history = loadHistory();
    final index = history.indexWhere((r) => r.id == recordId);
    if (index == -1) return;

    history[index] = history[index].copyWith(followUpCompleted: true);
    await _save(history);
  }

  int countDueFollowUps() {
    return loadHistory().where((r) => r.isFollowUpDue).length;
  }

  Future<void> clearHistory() async {
    await _prefs.remove(_storageKey);
  }

  Future<void> _save(List<ApplicationRecord> history) async {
    final encoded = jsonEncode(history.map((record) => record.toJson()).toList());
    await _prefs.setString(_storageKey, encoded);
  }
}
