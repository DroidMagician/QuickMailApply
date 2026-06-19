import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_email_draft.dart';
import '../models/job_post_context.dart';
import '../models/job_profile.dart';
import 'settings_repository.dart';

enum EmailTone { professional, confident, friendly }

class AiEmailService {
  AiEmailService(this._settings);

  final SettingsRepository _settings;

  static const _geminiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  Future<AiEmailDraft> generate({
    required JobProfile profile,
    required String jobTitle,
    String? company,
    String? postWording,
    JobPostContext? postContext,
    EmailTone tone = EmailTone.professional,
  }) async {
    final apiKey = _settings.geminiApiKey;
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        return await _generateWithGemini(
          apiKey: apiKey,
          profile: profile,
          jobTitle: jobTitle,
          company: company,
          postWording: postWording,
          postContext: postContext,
          tone: tone,
        );
      } catch (_) {
        // Fall back to local smart template if API fails.
      }
    }

    return _generateLocally(
      profile: profile,
      jobTitle: jobTitle,
      company: company,
      postWording: postWording,
      postContext: postContext,
      tone: tone,
    );
  }

  Future<AiEmailDraft> _generateWithGemini({
    required String apiKey,
    required JobProfile profile,
    required String jobTitle,
    String? company,
    String? postWording,
    JobPostContext? postContext,
    required EmailTone tone,
  }) async {
    final applicant = _settings.applicantName;
    final skills = postContext?.skills.join(', ') ?? '';
    final prompt = '''
Write a concise job application email for a candidate applying via LinkedIn.

Profile/role focus: ${profile.name}
Job title from post: $jobTitle
Company: ${company ?? 'Not specified'}
Candidate name: ${applicant.isEmpty ? '[Your Name]' : applicant}
Tone: ${tone.name}
LinkedIn post excerpt: ${postWording ?? postContext?.rawText ?? 'Not provided'}
Detected skills in post: ${skills.isEmpty ? 'Not specified' : skills}

Return ONLY valid JSON with keys "subject" and "body".
Keep body under 180 words, professional, no markdown.
Mention the attached resume.
''';

    final response = await http.post(
      Uri.parse('$_geminiUrl?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 512,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
    if (text == null || text.isEmpty) {
      throw Exception('Empty Gemini response');
    }

    final parsed = _parseJsonFromText(text);
    return AiEmailDraft(
      subject: parsed['subject'] as String? ?? 'Application for $jobTitle',
      body: parsed['body'] as String? ?? text,
      generatedByAi: true,
    );
  }

  AiEmailDraft _generateLocally({
    required JobProfile profile,
    required String jobTitle,
    String? company,
    String? postWording,
    JobPostContext? postContext,
    required EmailTone tone,
  }) {
    final applicant = _settings.applicantName;
    final name = applicant.isEmpty ? '[Your Name]' : applicant;
    final companyPhrase = company != null && company.isNotEmpty ? ' at $company' : '';
    final skills = postContext?.skills ?? const [];
    final skillsLine = skills.isNotEmpty
        ? '\nI noticed your post highlights ${skills.take(4).join(', ')} — which aligns closely with my background.'
        : '';

    final greeting = switch (tone) {
      EmailTone.professional => 'Dear Hiring Manager,',
      EmailTone.confident => 'Hello,',
      EmailTone.friendly => 'Hi there,',
    };

    final closing = switch (tone) {
      EmailTone.professional => 'Thank you for your time and consideration.\n\nBest regards,\n$name',
      EmailTone.confident =>
        'I would welcome a conversation about how I can contribute to your team.\n\nRegards,\n$name',
      EmailTone.friendly => 'Looking forward to hearing from you!\n\nCheers,\n$name',
    };

    final postHint = (postWording ?? postContext?.rawText)?.trim();
    final contextLine = postHint != null && postHint.length > 20
        ? '\nI came across your LinkedIn post regarding the $jobTitle opening and wanted to reach out directly.'
        : '';

    final body = '''
$greeting

I am writing to express my strong interest in the $jobTitle position$companyPhrase.$contextLine$skillsLine

As a ${profile.name}, I believe my experience is a strong match for this role. Please find my resume attached for your review.

$closing''';

    return AiEmailDraft(
      subject: 'Application for $jobTitle${companyPhrase.isEmpty ? '' : ' — $company'}',
      body: body.trim(),
      generatedByAi: false,
    );
  }

  Map<String, dynamic> _parseJsonFromText(String text) {
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (match != null) {
        return jsonDecode(match.group(0)!) as Map<String, dynamic>;
      }
      rethrow;
    }
  }
}
