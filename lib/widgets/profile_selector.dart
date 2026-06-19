import 'package:flutter/material.dart';

import '../models/job_profile.dart';
import '../theme/app_theme.dart';
import 'app_widgets.dart';

/// Visual step label for the apply flow.
class StepBadge extends StatelessWidget {
  const StepBadge({
    super.key,
    required this.step,
    required this.title,
    this.subtitle,
  });

  final int step;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.headerGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$step',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Horizontal profile cards — primary way to pick Flutter / Android / Team Lead profiles.
class ProfileSelectorPanel extends StatelessWidget {
  const ProfileSelectorPanel({
    super.key,
    required this.profiles,
    required this.selectedProfileId,
    required this.onProfileSelected,
    required this.onManageProfiles,
    this.onEditProfile,
  });

  final List<JobProfile> profiles;
  final String? selectedProfileId;
  final ValueChanged<JobProfile> onProfileSelected;
  final VoidCallback onManageProfiles;
  final void Function(JobProfile)? onEditProfile;

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.work_outline_rounded, color: AppColors.primary.withValues(alpha: 0.9)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Create your first application profile',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Each profile stores its own email template and resume — e.g. Flutter Developer, Android Developer, Team Lead.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onManageProfiles,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create application profile'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${profiles.length} profile${profiles.length == 1 ? '' : 's'} saved',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            TextButton.icon(
              onPressed: onManageProfiles,
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Manage all'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: profiles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final profile = profiles[index];
              final selected = profile.id == selectedProfileId;
              return _ProfileCard(
                profile: profile,
                selected: selected,
                onTap: () => onProfileSelected(profile),
                onEdit: onEditProfile == null ? null : () => onEditProfile!(profile),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.selected,
    required this.onTap,
    this.onEdit,
  });

  final JobProfile profile;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  IconData get _roleIcon {
    final name = profile.name.toLowerCase();
    if (name.contains('flutter')) return Icons.phone_android_rounded;
    if (name.contains('android')) return Icons.android_rounded;
    if (name.contains('lead') || name.contains('manager')) return Icons.groups_rounded;
    return Icons.person_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: Material(
        color: selected ? AppColors.primaryContainer : Colors.white,
        elevation: selected ? 2 : 0,
        shadowColor: AppColors.primary.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _roleIcon,
                        size: 20,
                        color: selected ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (selected)
                      Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                    else if (onEdit != null)
                      InkWell(
                        onTap: onEdit,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  profile.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      profile.hasResume ? Icons.picture_as_pdf_rounded : Icons.warning_amber_rounded,
                      size: 14,
                      color: profile.hasResume ? AppColors.success : AppColors.accentWarm,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        profile.hasResume ? 'Resume ready' : 'No resume',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: profile.hasResume ? AppColors.success : AppColors.accentWarm,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Branding for the resume analysis feature.
abstract final class ResumeFitAnalyzer {
  static const title = 'Resume Fit Analyzer';
  static const subtitle = 'How well your resume matches each role';
  static const analyzeButton = 'Analyze resume fit';
  static const analyzingLabel = 'Analyzing fit…';
}
