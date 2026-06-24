import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/application_record.dart';
import '../services/application_history_repository.dart';
import '../services/gmail_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.historyRepository,
    required this.gmailService,
    this.onReapply,
  });

  final ApplicationHistoryRepository historyRepository;
  final GmailService gmailService;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkReplies(showFeedback: false);
    });
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

  bool _syncing = false;

  Future<void> _checkReplies({bool showFeedback = true}) async {
    final signedIn = await widget.gmailService.isSignedIn;
    if (!signedIn) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please connect your Gmail account in Settings first to sync replies.')),
        );
      }
      return;
    }

    final userEmail = await widget.gmailService.currentUserEmail;
    if (userEmail == null) return;

    setState(() => _syncing = true);

    int updatedCount = 0;
    try {
      final records = widget.historyRepository.loadHistory();
      final pendingRecords = records.where((r) => r.gmailThreadId != null && r.replyStatus == 'sent').toList();

      for (final record in pendingRecords) {
        final result = await widget.gmailService.checkReplyStatus(record.gmailThreadId!, userEmail);
        if (result != null) {
          final status = result['status'] as String;
          final snippet = result['snippet'] as String?;

          if (status != record.replyStatus) {
            await widget.historyRepository.updateReplyStatus(
              recordId: record.id,
              replyStatus: status,
              snippet: snippet,
            );
            updatedCount++;
          }
        }
      }

      if (mounted && (showFeedback || updatedCount > 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updatedCount > 0
                ? 'Check complete! Found $updatedCount new recruiter response(s).'
                : 'Checked for replies. No new responses found.'),
          ),
        );
      }
    } catch (e) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to check replies: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
          _loadHistory();
        });
      }
    }
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
              if (_history.isNotEmpty) ...[
                if (_syncing)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Check replies',
                    onPressed: _checkReplies,
                    icon: const Icon(Icons.sync_rounded, color: Colors.white),
                  ),
                IconButton(
                  tooltip: 'Clear history',
                  onPressed: _clearHistory,
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                ),
              ],
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
                                if (record.replyStatus == 'sent') ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Direct',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                                if (record.replyStatus == 'replied') ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Replied!',
                                      style: TextStyle(
                                        color: AppColors.success,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                                if (record.isFollowUpDue) ...[
                                  const SizedBox(width: 6),
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
                              ],
                            ),
                            if (record.replyStatus == 'replied' && record.lastReplySnippet != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.success.withValues(alpha: 0.15)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.reply_all_rounded, size: 16, color: AppColors.success),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Latest Recruiter Reply',
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                color: AppColors.success,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      record.lastReplySnippet!,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            fontStyle: FontStyle.italic,
                                            height: 1.35,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                            if (record.lastCheckedAt != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Checked for replies: ${DateFormat('MMM d, h:mm a').format(record.lastCheckedAt!)}',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                                      fontSize: 9,
                                    ),
                              ),
                            ],
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
