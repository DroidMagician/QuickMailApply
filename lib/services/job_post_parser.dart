import '../models/job_post_context.dart';
import '../utils/email_validator.dart';

class JobPostParser {
  static const _techKeywords = [
    'flutter',
    'dart',
    'android',
    'kotlin',
    'java',
    'swift',
    'ios',
    'react',
    'node',
    'python',
    'aws',
    'firebase',
    'graphql',
    'rest',
    'api',
    'bloc',
    'provider',
    'riverpod',
    'mvvm',
    'clean architecture',
    'jetpack compose',
    'ci/cd',
    'agile',
    'scrum',
    'leadership',
    'mentoring',
  ];

  static JobPostContext parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const JobPostContext();

    return JobPostContext(
      email: extractEmailFromText(trimmed),
      jobTitle: _extractJobTitle(trimmed),
      company: _extractCompany(trimmed),
      skills: _extractSkills(trimmed),
      rawText: trimmed,
    );
  }

  static String? _extractJobTitle(String text) {
    final patterns = [
      RegExp(
        r'(?:hiring|looking for|seeking|opening for|role:?|position:?)\s+[a\s]*(.{5,60}?)(?:\s+at|\s+for|\s*\||\s*\.|\s*\n|$)',
        caseSensitive: false,
      ),
      RegExp(
        r'((?:senior|sr\.?|lead|junior|mid[- ]level|staff|principal)\s+[\w\s/+-]{3,40}(?:developer|engineer|architect|lead))',
        caseSensitive: false,
      ),
      RegExp(
        r'#([\w\s/+-]{3,40}(?:developer|engineer|lead|architect))',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final title = _cleanCapture(match.group(1));
        if (title != null && title.length >= 4) return title;
      }
    }
    return null;
  }

  static String? _extractCompany(String text) {
    final patterns = [
      RegExp(r'(?:at|@|join)\s+([A-Z][\w&.\- ]{2,40})(?:\s+[!.,\n|]|$)', caseSensitive: false),
      RegExp(r'([A-Z][\w&.\- ]{2,40})\s+is hiring', caseSensitive: false),
      RegExp(r'company:\s*([^\n,|]{2,40})', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final company = _cleanCapture(match.group(1));
        if (company != null && !_looksLikeJobTitle(company)) return company;
      }
    }
    return null;
  }

  static List<String> _extractSkills(String text) {
    final lower = text.toLowerCase();
    final found = <String>[];
    for (final keyword in _techKeywords) {
      if (lower.contains(keyword)) {
        found.add(keyword.split(' ').map(_capitalizeWord).join(' '));
      }
    }
    return found.toSet().take(8).toList();
  }

  static String? _cleanCapture(String? value) {
    if (value == null) return null;
    final cleaned = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return null;
    return cleaned;
  }

  static bool _looksLikeJobTitle(String value) {
    final lower = value.toLowerCase();
    return lower.contains('developer') ||
        lower.contains('engineer') ||
        lower.contains('lead') ||
        lower.contains('hiring');
  }

  static String _capitalizeWord(String word) {
    if (word.isEmpty) return word;
    if (word == 'ios') return 'iOS';
    if (word == 'aws') return 'AWS';
    if (word == 'ci/cd') return 'CI/CD';
    return word[0].toUpperCase() + word.substring(1);
  }
}
