import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/application_record.dart';
import '../services/application_history_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.historyRepository,
    this.onReapply,
  });

  final ApplicationHistoryRepository historyRepository;
  final void Function(String email, String profileId)? onReapply;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ApplicationRecord> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() => _history = widget.historyRepository.loadHistory());
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear history?'),
        content: const Text('This removes all saved application records from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );

    if (confirmed != true) return;

    await widget.historyRepository.clearHistory();
    _loadHistory();
  }

  Future<void> _markFollowUpDone(ApplicationRecord record) async {
    await widget.historyRepository.markFollowUpDone(record.id);
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy · h:mm a');
    final dueCount = _history.where((r) => r.isFollowUpDue).length;

    return ColoredBox(
      color: AppColors.surface,
      child: Column(
        children: [
          GradientHeader(
            title: 'Application History',
            subtitle: 'Track applications & follow-ups',
            actions: [
              if (_history.isNotEmpty)
                IconButton(
                  tooltip: 'Clear history',
                  onPressed: _clearHistory,
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                ),
            ],
          ),
          if (dueCount > 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accentWarm.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accentWarm.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: AppColors.accentWarm, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    '$dueCount follow-up${dueCount > 1 ? 's' : ''} due today',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _history.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.history_rounded, size: 40, color: AppColors.primary),
                          ),
                          const SizedBox(height: 20),
                          Text('No applications yet', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(
                            'Each Apply saves the recruiter email here with an automatic follow-up reminder.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _history.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final record = _history[index];
                      return AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.primaryContainer,
                                  foregroundColor: AppColors.primary,
                                  child: Text(
                                    record.profileName.isNotEmpty ? record.profileName[0].toUpperCase() : '?',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        record.recruiterEmail,
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                      ),
                                      Text(
                                        record.profileName,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                if (record.isFollowUpDue)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Follow up',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: AppColors.error,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                            if (record.jobTitle != null) ...[
                              const SizedBox(height: 10),
                              Text(record.jobTitle!, style: Theme.of(context).textTheme.bodyMedium),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              record.subject,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              dateFormat.format(record.appliedAt),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
                            ),
                            if (record.followUpAt != null && !record.followUpCompleted) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Follow up by ${DateFormat('MMM d').format(record.followUpAt!)}',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.accentWarm),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (record.isFollowUpDue)
                                  TextButton.icon(
                                    onPressed: () => _markFollowUpDone(record),
                                    icon: const Icon(Icons.check_circle_outline, size: 18),
                                    label: const Text('Done'),
                                  ),
                                if (widget.onReapply != null)
                                  FilledButton.tonalIcon(
                                    onPressed: () => widget.onReapply!(
                                      record.recruiterEmail,
                                      record.profileId,
                                    ),
                                    icon: const Icon(Icons.replay_rounded, size: 18),
                                    label: const Text('Re-apply'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
