import 'package:flutter/material.dart';

import '../services/application_history_repository.dart';
import '../services/profile_repository.dart';
import '../services/settings_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/profile_selector.dart';
import 'ai_email_screen.dart';
import 'resume_score_screen.dart';
import 'settings_screen.dart';
import '../services/gmail_service.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({
    super.key,
    required this.profileRepository,
    required this.settingsRepository,
    required this.historyRepository,
    required this.gmailService,
    this.onProfileUpdated,
  });

  final ProfileRepository profileRepository;
  final SettingsRepository settingsRepository;
  final ApplicationHistoryRepository historyRepository;
  final GmailService gmailService;
  final VoidCallback? onProfileUpdated;

  @override
  Widget build(BuildContext context) {
    final dueFollowUps = historyRepository.countDueFollowUps();

    return ColoredBox(
      color: AppColors.surface,
      child: Column(
        children: [
          GradientHeader(
            title: 'Career Tools',
            subtitle: 'AI writing, resume insights & more',
            actions: [
              IconButton(
                tooltip: 'Settings',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(
                        repository: settingsRepository,
                        gmailService: gmailService,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (dueFollowUps > 0) ...[
                  AppCard(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentWarm.withValues(alpha: 0.15),
                        AppColors.accentWarm.withValues(alpha: 0.05),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accentWarm.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.notifications_active_rounded, color: AppColors.accentWarm),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$dueFollowUps follow-up${dueFollowUps > 1 ? 's' : ''} due',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'Check History tab to re-apply or mark done.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _ToolCard(
                  icon: Icons.auto_awesome,
                  iconColor: AppColors.primary,
                  iconBg: AppColors.primaryContainer,
                  title: 'AI Email Generator',
                  subtitle: settingsRepository.hasGeminiApiKey
                      ? 'Gemini-powered tailored emails from job posts'
                      : 'Smart templates · Add Gemini key in Settings for full AI',
                  onTap: () async {
                    final profiles = profileRepository.loadProfiles();
                    if (profiles.isEmpty) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Create a profile first')),
                      );
                      return;
                    }
                    final updated = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => AiEmailScreen(
                          profileRepository: profileRepository,
                          settingsRepository: settingsRepository,
                          profiles: profiles,
                        ),
                      ),
                    );
                    if (updated == true) onProfileUpdated?.call();
                  },
                ),
                const SizedBox(height: 12),
                _ToolCard(
                  icon: Icons.insights_rounded,
                  iconColor: AppColors.accent,
                  iconBg: AppColors.secondaryContainer,
                  title: ResumeFitAnalyzer.title,
                  subtitle: ResumeFitAnalyzer.subtitle,
                  onTap: () async {
                    final profiles = await profileRepository.loadProfilesWithMigration();
                    if (profiles.isEmpty) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Create a profile first on the Apply tab')),
                      );
                      return;
                    }
                    if (!context.mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ResumeScoreScreen(
                          repository: profileRepository,
                          profiles: profiles,
                          onProfilesUpdated: onProfileUpdated,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _ToolCard(
                  icon: Icons.document_scanner_outlined,
                  iconColor: AppColors.accentWarm,
                  iconBg: AppColors.tertiaryContainer,
                  title: 'LinkedIn Post Parser',
                  subtitle: 'Share posts to auto-extract email, role, company & skills',
                  onTap: () {
                    showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('LinkedIn Post Parser'),
                        content: const Text(
                          'Long-press a LinkedIn job post → Share → QuickMail Apply.\n\n'
                          'Extracts recruiter email, job title, company, and tech skills automatically.',
                        ),
                        actions: [
                          FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Got it'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textSecondary.withValues(alpha: 0.6)),
        ],
      ),
    );
  }
}
