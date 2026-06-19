import 'package:flutter/material.dart';

import '../models/ai_email_draft.dart';
import '../models/job_post_context.dart';
import '../models/job_profile.dart';
import '../services/ai_email_service.dart';
import '../services/job_post_parser.dart';
import '../services/profile_repository.dart';
import '../services/settings_repository.dart';

class AiEmailScreen extends StatefulWidget {
  const AiEmailScreen({
    super.key,
    required this.profileRepository,
    required this.settingsRepository,
    required this.profiles,
    this.initialContext,
  });

  final ProfileRepository profileRepository;
  final SettingsRepository settingsRepository;
  final List<JobProfile> profiles;
  final JobPostContext? initialContext;

  @override
  State<AiEmailScreen> createState() => _AiEmailScreenState();
}

class _AiEmailScreenState extends State<AiEmailScreen> {
  late final AiEmailService _aiService;
  late String? _selectedProfileId;
  late final TextEditingController _jobTitleController;
  late final TextEditingController _companyController;
  late final TextEditingController _wordingController;
  late final TextEditingController _subjectController;
  late final TextEditingController _bodyController;

  EmailTone _tone = EmailTone.professional;
  bool _generating = false;
  AiEmailDraft? _lastDraft;

  @override
  void initState() {
    super.initState();
    _aiService = AiEmailService(widget.settingsRepository);
    _selectedProfileId = widget.profiles.isNotEmpty ? widget.profiles.first.id : null;

    final ctx = widget.initialContext;
    _jobTitleController = TextEditingController(text: ctx?.jobTitle ?? '');
    _companyController = TextEditingController(text: ctx?.company ?? '');
    _wordingController = TextEditingController(text: ctx?.rawText ?? '');
    _subjectController = TextEditingController();
    _bodyController = TextEditingController();
  }

  @override
  void dispose() {
    _jobTitleController.dispose();
    _companyController.dispose();
    _wordingController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  JobProfile? get _selectedProfile {
    if (_selectedProfileId == null) return null;
    for (final p in widget.profiles) {
      if (p.id == _selectedProfileId) return p;
    }
    return null;
  }

  Future<void> _generate() async {
    final profile = _selectedProfile;
    final jobTitle = _jobTitleController.text.trim();

    if (profile == null) {
      _showSnack('Select a profile');
      return;
    }
    if (jobTitle.isEmpty) {
      _showSnack('Enter a job title (e.g. Senior Flutter Developer)');
      return;
    }

    setState(() => _generating = true);
    try {
      final postContext = JobPostParser.parse(_wordingController.text);
      final draft = await _aiService.generate(
        profile: profile,
        jobTitle: jobTitle,
        company: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
        postWording: _wordingController.text.trim().isEmpty ? null : _wordingController.text.trim(),
        postContext: postContext.skills.isNotEmpty ? postContext : widget.initialContext,
        tone: _tone,
      );

      setState(() {
        _lastDraft = draft;
        _subjectController.text = draft.subject;
        _bodyController.text = draft.body;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            draft.generatedByAi ? 'Generated with Gemini AI' : 'Generated with smart template',
          ),
        ),
      );
    } catch (error) {
      _showSnack('Generation failed: $error');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _saveToProfile() async {
    final profile = _selectedProfile;
    if (profile == null) return;

    if (_subjectController.text.trim().isEmpty || _bodyController.text.trim().isEmpty) {
      _showSnack('Generate or enter subject and body first');
      return;
    }

    final updated = profile.copyWith(
      subject: _subjectController.text.trim(),
      body: _bodyController.text.trim(),
    );

    final profiles = widget.profileRepository.loadProfiles();
    final index = profiles.indexWhere((p) => p.id == updated.id);
    if (index != -1) {
      profiles[index] = updated;
      await widget.profileRepository.saveProfiles(profiles);
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Email Generator'),
        actions: [
          TextButton(
            onPressed: _saveToProfile,
            child: const Text('Save to profile'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Profile', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.profiles.map((profile) {
                return FilterChip(
                  label: Text(profile.name),
                  selected: profile.id == _selectedProfileId,
                  onSelected: (_) => setState(() => _selectedProfileId = profile.id),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _jobTitleController,
              decoration: const InputDecoration(
                labelText: 'Job title',
                hintText: 'Senior Flutter Developer',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _companyController,
              decoration: const InputDecoration(
                labelText: 'Company (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _wordingController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'LinkedIn post wording (optional)',
                hintText: 'Paste the job post text for better personalization…',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Tone', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<EmailTone>(
              segments: const [
                ButtonSegment(value: EmailTone.professional, label: Text('Professional')),
                ButtonSegment(value: EmailTone.confident, label: Text('Confident')),
                ButtonSegment(value: EmailTone.friendly, label: Text('Friendly')),
              ],
              selected: {_tone},
              onSelectionChanged: (value) => setState(() => _tone = value.first),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _generating ? null : _generate,
              icon: _generating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: Text(_generating ? 'Generating…' : 'Generate email'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            if (_lastDraft != null) ...[
              const SizedBox(height: 24),
              TextField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyController,
                minLines: 10,
                maxLines: 20,
                decoration: const InputDecoration(
                  labelText: 'Email body',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
