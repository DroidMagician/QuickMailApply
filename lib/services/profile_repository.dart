import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/job_profile.dart';

class ProfileRepository {
  ProfileRepository(this._prefs);

  static const _storageKey = 'job_profiles_v1';
  static const _selectedProfileKey = 'selected_profile_id';

  final SharedPreferences _prefs;
  final _uuid = const Uuid();

  List<JobProfile> loadProfiles() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return _defaultProfiles();
    }

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => JobProfile.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _defaultProfiles();
    }
  }

  Future<List<JobProfile>> loadProfilesWithMigration() async {
    final profiles = loadProfiles();
    var changed = false;
    final migrated = <JobProfile>[];

    for (final profile in profiles) {
      if (!profile.hasResume) {
        migrated.add(profile);
        continue;
      }
      final resolved = await resolveShareableResumePath(profile.resumePath);
      if (resolved != null && resolved != profile.resumePath) {
        migrated.add(profile.copyWith(resumePath: resolved));
        changed = true;
      } else {
        migrated.add(profile);
      }
    }

    if (changed) {
      await saveProfiles(migrated);
    }
    return migrated;
  }

  Future<void> saveProfiles(List<JobProfile> profiles) async {
    final encoded = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await _prefs.setString(_storageKey, encoded);
  }

  String? loadSelectedProfileId() => _prefs.getString(_selectedProfileKey);

  Future<void> saveSelectedProfileId(String? id) async {
    if (id == null) {
      await _prefs.remove(_selectedProfileKey);
      return;
    }
    await _prefs.setString(_selectedProfileKey, id);
  }

  JobProfile createProfile({required String name}) {
    return JobProfile(
      id: _uuid.v4(),
      name: name,
      subject: 'Application for $name role',
      body: _defaultBody(name),
    );
  }

  Future<String> copyResumeToAppStorage({
    required String profileId,
    required String sourcePath,
  }) async {
    final supportDir = await getApplicationSupportDirectory();
    final resumesDir = Directory('${supportDir.path}/resumes');
    if (!await resumesDir.exists()) {
      await resumesDir.create(recursive: true);
    }

    final extension = _fileExtension(sourcePath);
    final destination = File('${resumesDir.path}/$profileId$extension');
    await File(sourcePath).copy(destination.path);
    return destination.path;
  }

  /// Ensures resume path is inside FileProvider-accessible storage (Android files dir).
  Future<String?> resolveShareableResumePath(String? path) async {
    if (path == null || path.isEmpty) return null;

    final file = File(path);
    if (!await file.exists()) return null;

    final supportDir = await getApplicationSupportDirectory();
    if (path.startsWith(supportDir.path)) return path;

    final resumesDir = Directory('${supportDir.path}/resumes');
    if (!await resumesDir.exists()) {
      await resumesDir.create(recursive: true);
    }

    final fileName = path.split('/').last;
    final destination = File('${resumesDir.path}/$fileName');
    await file.copy(destination.path);
    return destination.path;
  }

  Future<void> deleteResumeFile(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  List<JobProfile> _defaultProfiles() {
    return [
      JobProfile(
        id: _uuid.v4(),
        name: 'Flutter Developer',
        subject: 'Application for Flutter Developer position',
        body: _defaultBody('Flutter Developer'),
      ),
      JobProfile(
        id: _uuid.v4(),
        name: 'Android Developer',
        subject: 'Application for Android Developer position',
        body: _defaultBody('Android Developer'),
      ),
      JobProfile(
        id: _uuid.v4(),
        name: 'Team Lead',
        subject: 'Application for Team Lead position',
        body: _defaultBody('Team Lead'),
      ),
    ];
  }

  String _defaultBody(String role) {
    return '''Dear Hiring Manager,

I am writing to express my interest in the $role position. Please find my resume attached for your review.

I would welcome the opportunity to discuss how my experience aligns with your requirements.

Thank you for your time and consideration.

Best regards''';
  }

  String _fileExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1) return '.pdf';
    return path.substring(dotIndex);
  }
}
