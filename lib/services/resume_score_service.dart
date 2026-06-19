import 'dart:io';

import 'package:read_pdf_text/read_pdf_text.dart';

import '../models/job_profile.dart';
import '../models/resume_score_result.dart';

class ResumeScoreService {
  static const _roleKeywords = {
    'flutter': ['flutter', 'dart', 'widget', 'bloc', 'provider', 'riverpod', 'firebase'],
    'android': ['android', 'kotlin', 'java', 'jetpack', 'compose', 'gradle', 'mvvm'],
    'team lead': ['lead', 'leadership', 'mentor', 'architect', 'agile', 'scrum', 'team'],
    'lead': ['lead', 'leadership', 'mentor', 'architect', 'agile', 'scrum', 'team'],
  };

  static const _sectionKeywords = [
    'experience',
    'education',
    'skills',
    'projects',
    'summary',
    'objective',
    'certification',
  ];

  static const _actionVerbs = [
    'built',
    'developed',
    'led',
    'designed',
    'implemented',
    'improved',
    'delivered',
    'managed',
    'created',
    'optimized',
    'architected',
    'mentored',
  ];

  Future<ResumeScoreResult> scoreResume({
    required String filePath,
    required JobProfile profile,
  }) async {
    final text = await _extractText(filePath);
    return _scoreText(text: text, profile: profile);
  }

  Future<String> _extractText(String filePath) async {
    final extension = filePath.split('.').last.toLowerCase();
    if (extension == 'pdf') {
      try {
        return await ReadPdfText.getPDFtext(filePath);
      } catch (_) {
        return '';
      }
    }
    if (extension == 'txt') {
      return File(filePath).readAsString();
    }
    return '';
  }

  ResumeScoreResult _scoreText({
    required String text,
    required JobProfile profile,
  }) {
    final normalized = text.toLowerCase();
    final wordCount = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    if (text.trim().length < 50) {
      return ResumeScoreResult(
        totalScore: 0,
        grade: 'N/A',
        extractedPreview: text.isEmpty ? null : text.substring(0, text.length.clamp(0, 200)),
        items: const [
          ResumeScoreItem(
            label: 'Readable content',
            score: 0,
            maxScore: 100,
            feedback: 'Could not read enough text. Use a text-based PDF or paste content in profile.',
          ),
        ],
        tips: const [
          'Export your resume as a text-friendly PDF (not scanned image).',
          'Ensure the file is not password-protected.',
        ],
      );
    }

    final contactScore = _scoreContact(normalized);
    final structureScore = _scoreStructure(normalized);
    final keywordScore = _scoreKeywords(normalized, profile.name);
    final impactScore = _scoreImpact(normalized);
    final lengthScore = _scoreLength(wordCount);

    final items = [
      contactScore,
      structureScore,
      keywordScore,
      impactScore,
      lengthScore,
    ];

    final total = items.fold(0, (sum, item) => sum + item.score);

    return ResumeScoreResult(
      totalScore: total,
      grade: _gradeForScore(total),
      items: items,
      tips: _buildTips(items, profile.name),
      extractedPreview: text.length > 300 ? '${text.substring(0, 300)}…' : text,
    );
  }

  ResumeScoreItem _scoreContact(String text) {
    final hasEmail = RegExp(r'[\w.\+-]+@[\w.-]+\.[a-z]{2,}').hasMatch(text);
    final hasPhone = RegExp(r'(\+?\d[\d\s\-()]{7,}\d)').hasMatch(text);
    final hasLinkedIn = text.contains('linkedin');

    var score = 0;
    if (hasEmail) score += 8;
    if (hasPhone) score += 6;
    if (hasLinkedIn) score += 6;

    return ResumeScoreItem(
      label: 'Contact information',
      score: score,
      maxScore: 20,
      feedback: [
        if (!hasEmail) 'Add a professional email address.',
        if (!hasPhone) 'Add a phone number.',
        if (!hasLinkedIn) 'Add your LinkedIn profile URL.',
        if (hasEmail && hasPhone && hasLinkedIn) 'Contact section looks complete.',
      ].first,
    );
  }

  ResumeScoreItem _scoreStructure(String text) {
    final found = _sectionKeywords.where(text.contains).length;
    final score = (found * 4).clamp(0, 20);

    return ResumeScoreItem(
      label: 'Structure & sections',
      score: score,
      maxScore: 20,
      feedback: found >= 4
          ? 'Good section coverage (experience, skills, etc.).'
          : 'Add clear sections: Summary, Experience, Skills, Projects, Education.',
    );
  }

  ResumeScoreItem _scoreKeywords(String text, String profileName) {
    final keywords = _keywordsForProfile(profileName);
    final matches = keywords.where(text.contains).length;
    final score = ((matches / keywords.length) * 30).round().clamp(0, 30);

    return ResumeScoreItem(
      label: 'Role keyword match',
      score: score,
      maxScore: 30,
      feedback: matches >= 4
          ? 'Strong match for $profileName keywords.'
          : 'Add more $profileName-specific skills and tools to your resume.',
    );
  }

  ResumeScoreItem _scoreImpact(String text) {
    final matches = _actionVerbs.where(text.contains).length;
    final score = (matches * 2).clamp(0, 20);

    return ResumeScoreItem(
      label: 'Impact & action verbs',
      score: score,
      maxScore: 20,
      feedback: matches >= 5
          ? 'Good use of action verbs (built, led, delivered…).'
          : 'Use stronger action verbs and quantify results (%, users, revenue).',
    );
  }

  ResumeScoreItem _scoreLength(int wordCount) {
    final score = switch (wordCount) {
      < 250 => 4,
      >= 250 && <= 900 => 10,
      > 900 && <= 1200 => 7,
      _ => 5,
    };

    return ResumeScoreItem(
      label: 'Length & readability',
      score: score,
      maxScore: 10,
      feedback: wordCount >= 250 && wordCount <= 900
          ? 'Resume length is in a good range (~1–2 pages).'
          : wordCount < 250
              ? 'Resume may be too short — add more detail on projects and impact.'
              : 'Resume may be too long — trim less relevant details.',
    );
  }

  List<String> _keywordsForProfile(String profileName) {
    final lower = profileName.toLowerCase();
    for (final entry in _roleKeywords.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return ['experience', 'project', 'team', 'development', 'software'];
  }

  String _gradeForScore(int score) {
    if (score >= 85) return 'A';
    if (score >= 70) return 'B';
    if (score >= 55) return 'C';
    if (score >= 40) return 'D';
    return 'F';
  }

  List<String> _buildTips(List<ResumeScoreItem> items, String profileName) {
    final tips = <String>[];
    for (final item in items) {
      if (item.score < item.maxScore * 0.7) {
        tips.add(item.feedback);
      }
    }
    if (tips.isEmpty) {
      tips.add('Your resume is well optimized for $profileName roles. Keep it updated!');
    }
    tips.add('Tailor keywords to each job post before applying.');
    return tips.take(4).toList();
  }
}
