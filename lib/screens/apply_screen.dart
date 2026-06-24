import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/job_post_context.dart';
import '../models/job_profile.dart';
import '../services/application_history_repository.dart';
import '../services/email_launcher.dart';
import '../services/profile_repository.dart';
import '../services/settings_repository.dart';
import '../theme/app_theme.dart';
import '../utils/email_validator.dart';
import '../widgets/app_widgets.dart';
import '../widgets/profile_selector.dart';
import 'ai_email_screen.dart';
import 'profile_form_screen.dart';
import 'profiles_screen.dart';
import '../services/gmail_service.dart';

class ApplyScreen extends StatefulWidget {
  const ApplyScreen({
    super.key,
    required this.profileRepository,
    required this.historyRepository,
    required this.settingsRepository,
    required this.gmailService,
    this.initialEmail,
    this.jobContext,
    this.onProfilesUpdated,
  });

  final ProfileRepository profileRepository;
  final ApplicationHistoryRepository historyRepository;
  final SettingsRepository settingsRepository;
  final GmailService gmailService;
  final String? initialEmail;
  final JobPostContext? jobContext;
  final VoidCallback? onProfilesUpdated;

  @override
  State<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends State<ApplyScreen> {
  late final TextEditingController _emailController;
  List<JobProfile> _profiles = [];
  String? _selectedProfileId;
  bool _loading = true;
  bool _applying = false;
  bool _gmailConnected = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    _bootstrap();
    widget.gmailService.addListener(_onGmailStatusChanged);
  }

  @override
  void didUpdateWidget(covariant ApplyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialEmail != null &&
        widget.initialEmail != oldWidget.initialEmail &&
        widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
    if (widget.gmailService != oldWidget.gmailService) {
      oldWidget.gmailService.removeListener(_onGmailStatusChanged);
      widget.gmailService.addListener(_onGmailStatusChanged);
      _checkGmailConnection();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    widget.gmailService.removeListener(_onGmailStatusChanged);
    super.dispose();
  }

  void _onGmailStatusChanged() {
    _checkGmailConnection();
  }

  Future<void> _checkGmailConnection() async {
    final connected = await widget.gmailService.isSignedIn;
    if (mounted && connected != _gmailConnected) {
      setState(() {
        _gmailConnected = connected;
      });
    }
  }

  Future<void> _bootstrap() async {
    final profiles = await widget.profileRepository.loadProfilesWithMigration();
    final selectedId = widget.profileRepository.loadSelectedProfileId();
    await _checkGmailConnection();

    setState(() {
      _profiles = profiles;
      _selectedProfileId = selectedId ?? (profiles.isNotEmpty ? profiles.first.id : null);
      _loading = false;
    });
  }

  JobProfile? get _selectedProfile {
    if (_selectedProfileId == null) return null;
    for (final profile in _profiles) {
      if (profile.id == _selectedProfileId) return profile;
    }
    return null;
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty')),
      );
      return;
    }

    final email = extractEmailFromText(text) ?? text;
    _emailController.text = email;
    setState(() {});
  }

  Future<void> _openProfiles() async {
    final updated = await Navigator.of(context).push<List<JobProfile>>(
      MaterialPageRoute(
        builder: (_) => ProfilesScreen(
          repository: widget.profileRepository,
          profiles: _profiles,
        ),
      ),
    );

    if (updated != null) {
      setState(() {
        _profiles = updated;
        if (_selectedProfileId != null &&
            !updated.any((profile) => profile.id == _selectedProfileId)) {
          _selectedProfileId = updated.isNotEmpty ? updated.first.id : null;
        }
      });
      await widget.profileRepository.saveSelectedProfileId(_selectedProfileId);
    }
  }

  Future<void> _editSelectedProfile() async {
    final profile = _selectedProfile;
    if (profile == null) return;

    final updated = await Navigator.of(context).push<JobProfile>(
      MaterialPageRoute(
        builder: (_) => ProfileFormScreen(
          repository: widget.profileRepository,
          profile: profile,
          settingsRepository: widget.settingsRepository,
          jobContext: widget.jobContext,
        ),
      ),
    );

    if (updated != null) {
      final index = _profiles.indexWhere((item) => item.id == updated.id);
      if (index != -1) {
        setState(() => _profiles[index] = updated);
        await widget.profileRepository.saveProfiles(_profiles);
      }
    }
  }

  Future<void> _openAiGenerator() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AiEmailScreen(
          profileRepository: widget.profileRepository,
          settingsRepository: widget.settingsRepository,
          profiles: _profiles,
          initialContext: widget.jobContext,
        ),
      ),
    );

    if (updated == true) {
      await _bootstrap();
      widget.onProfilesUpdated?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile email updated from AI generator')),
      );
    }
  }

  Future<void> _apply() async {
    final email = _emailController.text.trim();
    var profile = _selectedProfile;

    if (!isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid recruiter email')),
      );
      return;
    }

    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a profile first')),
      );
      return;
    }

    setState(() => _applying = true);

    try {
      String? attachmentPath;
      if (profile.hasResume) {
        attachmentPath = await widget.profileRepository.resolveShareableResumePath(profile.resumePath);
        if (attachmentPath != null && attachmentPath != profile.resumePath) {
          profile = profile.copyWith(resumePath: attachmentPath);
          final index = _profiles.indexWhere((p) => p.id == profile!.id);
          if (index != -1) {
            _profiles[index] = profile;
            await widget.profileRepository.saveProfiles(_profiles);
          }
        }
      }

      if (_gmailConnected) {
        final result = await widget.gmailService.sendDirectEmail(
          to: email,
          subject: profile.subject,
          body: profile.body,
          attachmentPath: attachmentPath,
          attachmentFileName: profile.resumeFileName,
        );

        await widget.profileRepository.saveSelectedProfileId(profile.id);
        await widget.historyRepository.addRecord(
          recruiterEmail: email,
          profileId: profile.id,
          profileName: profile.name,
          subject: profile.subject,
          jobTitle: widget.jobContext?.jobTitle,
          followUpDays: widget.settingsRepository.followUpDays,
          gmailMessageId: result['id'],
          gmailThreadId: result['threadId'],
          replyStatus: 'sent',
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application sent successfully directly via Gmail!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        await EmailLauncher.openCompose(
          email: email,
          subject: profile.subject,
          body: profile.body,
          attachmentPath: attachmentPath,
        );
        await widget.profileRepository.saveSelectedProfileId(profile.id);
        await widget.historyRepository.addRecord(
          recruiterEmail: email,
          profileId: profile.id,
          profileName: profile.name,
          subject: profile.subject,
          jobTitle: widget.jobContext?.jobTitle,
          followUpDays: widget.settingsRepository.followUpDays,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_gmailConnected ? 'Direct send failed: $error' : EmailLauncher.friendlyError(error))),
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _selectedProfile;

    return ColoredBox(
      color: AppColors.surface,
      child: Column(
        children: [
          const GradientHeader(
            title: 'QuickMail Apply',
            subtitle: 'Pick a role profile, add the email, apply in one tap',
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    children: [
                      InfoBanner(
                        icon: Icons.touch_app_rounded,
                        message: 'Tap an email on LinkedIn → choose QuickMail Apply from the list. '
                            'If only Gmail appears, clear Gmail\'s "Open by default" in Android Settings.',
                      ),
                      if (widget.jobContext?.hasContext == true) ...[
                        const SizedBox(height: 14),
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.document_scanner_outlined, color: AppColors.accent, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Parsed from LinkedIn',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (widget.jobContext!.jobTitle != null)
                                _ContextRow(icon: Icons.work_outline, label: widget.jobContext!.jobTitle!),
                              if (widget.jobContext!.company != null)
                                _ContextRow(icon: Icons.business_outlined, label: widget.jobContext!.company!),
                              if (widget.jobContext!.skills.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: widget.jobContext!.skills
                                        .map((s) => Chip(
                                              label: Text(s),
                                              visualDensity: VisualDensity.compact,
                                              backgroundColor: AppColors.primaryContainer,
                                            ))
                                        .toList(),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: _openAiGenerator,
                                  icon: const Icon(Icons.auto_awesome, size: 18),
                                  label: const Text('Generate tailored email'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      const StepBadge(
                        step: 1,
                        title: 'Application profile',
                        subtitle: 'Flutter, Android, Team Lead — each with its own resume & email template.',
                      ),
                      const SizedBox(height: 16),
                      ProfileSelectorPanel(
                        profiles: _profiles,
                        selectedProfileId: _selectedProfileId,
                        onProfileSelected: (item) async {
                          setState(() => _selectedProfileId = item.id);
                          await widget.profileRepository.saveSelectedProfileId(item.id);
                        },
                        onManageProfiles: _openProfiles,
                        onEditProfile: (item) async {
                          setState(() => _selectedProfileId = item.id);
                          await widget.profileRepository.saveSelectedProfileId(item.id);
                          await _editSelectedProfile();
                        },
                      ),
                      const SizedBox(height: 28),
                      const StepBadge(
                        step: 2,
                        title: 'Recruiter email',
                        subtitle: 'Paste or tap the email from the LinkedIn post.',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: InputDecoration(
                          hintText: 'hr@company.com',
                          prefixIcon: Icon(Icons.alternate_email_rounded, color: AppColors.primary.withValues(alpha: 0.8)),
                          suffixIcon: IconButton(
                            tooltip: 'Paste from clipboard',
                            onPressed: _pasteFromClipboard,
                            icon: const Icon(Icons.content_paste_rounded),
                          ),
                        ),
                      ),
                      if (profile != null) ...[
                        const SizedBox(height: 28),
                        const StepBadge(
                          step: 3,
                          title: 'Review & apply',
                          subtitle: 'Opens Gmail or Mail with subject, body, and resume attached.',
                        ),
                        const SizedBox(height: 16),
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      profile.name,
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _editSelectedProfile,
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    label: const Text('Edit template'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _PreviewRow(label: 'Subject', value: profile.subject),
                              const Divider(height: 28),
                              _PreviewRow(label: 'Body', value: profile.body, maxLines: 4),
                              const Divider(height: 28),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: profile.hasResume
                                      ? AppColors.success.withValues(alpha: 0.08)
                                      : AppColors.error.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      profile.hasResume ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                                      color: profile.hasResume ? AppColors.success : AppColors.error,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        profile.hasResume
                                            ? 'Resume: ${profile.resumeFileName}'
                                            : 'No resume — tap edit on the profile card to attach',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      PrimaryActionButton(
                        label: _applying
                            ? (_gmailConnected ? 'Sending Email…' : EmailLauncher.applyingLabel())
                            : (_gmailConnected ? 'Apply & Send (1-Tap)' : EmailLauncher.applyButtonLabel()),
                        loading: _applying,
                        onPressed: _applying || profile == null ? null : _apply,
                      ),
                      if (!_gmailConnected)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Center(
                            child: TextButton.icon(
                              onPressed: () async {
                                final success = await widget.gmailService.signIn();
                                if (success) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Successfully connected Gmail account')),
                                  );
                                  _checkGmailConnection();
                                }
                              },
                              icon: const Icon(Icons.mail_outline_rounded, size: 18),
                              label: const Text(
                                'Connect Gmail for 1-tap apply & tracking',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ContextRow extends StatelessWidget {
  const _ContextRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    this.maxLines = 2,
  });

  final String label;
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
        ),
      ],
    );
  }
}
