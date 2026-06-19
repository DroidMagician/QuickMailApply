import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/job_profile.dart';
import '../models/resume_score_result.dart';
import '../services/profile_repository.dart';
import '../services/resume_score_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/profile_selector.dart';

class ResumeScoreScreen extends StatefulWidget {
  const ResumeScoreScreen({
    super.key,
    required this.repository,
    required this.profiles,
    this.onProfilesUpdated,
  });

  final ProfileRepository repository;
  final List<JobProfile> profiles;
  final VoidCallback? onProfilesUpdated;

  @override
  State<ResumeScoreScreen> createState() => _ResumeScoreScreenState();
}

class _ResumeScoreScreenState extends State<ResumeScoreScreen> {
  final _service = ResumeScoreService();
  late List<JobProfile> _profiles;
  String? _selectedProfileId;
  ResumeScoreResult? _result;
  bool _loading = false;
  bool _attaching = false;

  @override
  void initState() {
    super.initState();
    _profiles = List.of(widget.profiles);
    _selectedProfileId = _profiles.isNotEmpty ? _profiles.first.id : null;
  }

  JobProfile? get _selectedProfile {
    if (_selectedProfileId == null) return null;
    for (final p in _profiles) {
      if (p.id == _selectedProfileId) return p;
    }
    return null;
  }

  Future<void> _persistProfiles() async {
    await widget.repository.saveProfiles(_profiles);
    widget.onProfilesUpdated?.call();
  }

  Future<void> _attachResume() async {
    final profile = _selectedProfile;
    if (profile == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result == null || result.files.single.path == null) return;

    setState(() => _attaching = true);
    try {
      final path = await widget.repository.copyResumeToAppStorage(
        profileId: profile.id,
        sourcePath: result.files.single.path!,
      );
      final updated = profile.copyWith(resumePath: path);
      final index = _profiles.indexWhere((p) => p.id == profile.id);
      if (index != -1) {
        setState(() {
          _profiles[index] = updated;
          _result = null;
        });
        await _persistProfiles();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resume attached to ${profile.name}')),
      );
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  Future<void> _analyze() async {
    final profile = _selectedProfile;
    if (profile == null) return;

    if (!profile.hasResume) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attach a resume below, then analyze')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final shareable = await widget.repository.resolveShareableResumePath(profile.resumePath);
      final result = await _service.scoreResume(
        filePath: shareable ?? profile.resumePath!,
        profile: profile,
      );
      setState(() => _result = result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Analysis failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _scoreColor(int score) {
    if (score >= 85) return AppColors.success;
    if (score >= 70) return const Color(0xFF84CC16);
    if (score >= 55) return AppColors.accentWarm;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = _selectedProfile;
    final result = _result;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ResumeFitAnalyzer.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            Text(
              ResumeFitAnalyzer.subtitle,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        toolbarHeight: 72,
      ),
      body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                const StepBadge(
                  step: 1,
                  title: 'Choose application profile',
                  subtitle: 'We analyze your resume against keywords for that role.',
                ),
                const SizedBox(height: 16),
                ProfileSelectorPanel(
                  profiles: _profiles,
                  selectedProfileId: _selectedProfileId,
                  onProfileSelected: (p) => setState(() {
                    _selectedProfileId = p.id;
                    _result = null;
                  }),
                  onManageProfiles: () => Navigator.pop(context),
                ),
                if (profile != null) ...[
                  const SizedBox(height: 20),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary.withValues(alpha: 0.9)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                profile.hasResume ? 'Resume for ${profile.name}' : 'Attach resume for ${profile.name}',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (profile.hasResume) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    profile.resumeFileName ?? 'resume.pdf',
                                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                TextButton(onPressed: _attachResume, child: const Text('Replace')),
                              ],
                            ),
                          ),
                        ] else ...[
                          Text(
                            'This profile has no resume yet. Pick a PDF to analyze how well it fits the ${profile.name} role.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _attaching ? null : _attachResume,
                            icon: _attaching
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.upload_file_rounded),
                            label: Text(_attaching ? 'Attaching…' : 'Attach resume PDF'),
                            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryActionButton(
                  label: _loading ? ResumeFitAnalyzer.analyzingLabel : ResumeFitAnalyzer.analyzeButton,
                  icon: Icons.insights_rounded,
                  loading: _loading,
                  onPressed: _loading || profile == null ? null : _analyze,
                ),
                if (result != null) ...[
                  const SizedBox(height: 32),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Fit score',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: 132,
                          height: 132,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: result.totalScore / 100,
                                strokeWidth: 11,
                                backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.35),
                                color: _scoreColor(result.totalScore),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${result.totalScore}',
                                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    'Grade ${result.grade}',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: _scoreColor(result.totalScore),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('out of 100 for ${profile?.name ?? 'this role'}',
                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...result.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(item.label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                                ),
                                Text(
                                  '${item.score}/${item.maxScore}',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                minHeight: 8,
                                value: item.maxScore == 0 ? 0 : item.score / item.maxScore,
                                backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.4),
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.feedback,
                              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Improvement tips', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  ...result.tips.map(
                    (tip) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.tips_and_updates_outlined, size: 18, color: AppColors.accentWarm),
                          const SizedBox(width: 10),
                          Expanded(child: Text(tip, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4))),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
