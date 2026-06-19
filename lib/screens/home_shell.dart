import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/job_post_context.dart';
import '../services/application_history_repository.dart';
import '../services/job_post_parser.dart';
import '../services/profile_repository.dart';
import '../services/settings_repository.dart';
import '../services/incoming_link_service.dart';
import '../services/share_intent_service.dart';
import '../theme/app_theme.dart';
import '../utils/email_validator.dart';
import 'apply_screen.dart';
import 'history_screen.dart';
import 'tools_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  ProfileRepository? _profileRepository;
  ApplicationHistoryRepository? _historyRepository;
  SettingsRepository? _settingsRepository;
  bool _loading = true;
  int _tabIndex = 0;
  String? _sharedEmail;
  JobPostContext? _jobContext;
  int _applyScreenKey = 0;
  int _toolsRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    ShareIntentService.listen(_handleSharedText);
    IncomingLinkService.listenMailto(_handleMailtoEmail);
  }

  @override
  void dispose() {
    ShareIntentService.dispose();
    IncomingLinkService.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _profileRepository = ProfileRepository(prefs);
    _historyRepository = ApplicationHistoryRepository(prefs);
    _settingsRepository = SettingsRepository(prefs);

    await _profileRepository!.loadProfilesWithMigration();

    final mailto = await IncomingLinkService.getInitialMailto();
    final shared = await ShareIntentService.getInitialSharedText();
    JobPostContext? context;
    String? email;

    if (mailto != null && mailto.isNotEmpty) {
      email = extractEmailFromText(mailto) ?? mailto;
    } else if (shared != null && shared.isNotEmpty) {
      context = JobPostParser.parse(shared);
      email = context.email ?? extractEmailFromText(shared) ?? shared;
    }

    if (!mounted) return;
    setState(() {
      _jobContext = context;
      _sharedEmail = email;
      _loading = false;
    });

    if (email != null) {
      _showSharedSnackBar(context);
    }
  }

  void _handleMailtoEmail(String emailAddress) {
    final email = extractEmailFromText(emailAddress) ?? emailAddress.trim();
    if (email.isEmpty) return;

    setState(() {
      _sharedEmail = email;
      _tabIndex = 0;
      _applyScreenKey++;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email loaded: $email')),
      );
    });
  }

  void _handleSharedText(String text) {
    if (text.trim().isEmpty) return;

    final context = JobPostParser.parse(text);
    final email = context.email ?? extractEmailFromText(text) ?? text.trim();

    setState(() {
      _jobContext = context;
      _sharedEmail = email;
      _tabIndex = 0;
      _applyScreenKey++;
    });
    _showSharedSnackBar(context);
  }

  void _showSharedSnackBar(JobPostContext? jobContext) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final parts = <String>[];
      if (_sharedEmail != null) parts.add('Email: $_sharedEmail');
      if (jobContext?.jobTitle != null) parts.add('Role: ${jobContext!.jobTitle}');
      if (jobContext?.company != null) parts.add('Company: ${jobContext!.company}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parts.isEmpty ? 'Shared text loaded' : parts.join(' · '))),
      );
    });
  }

  void _reapplyFromHistory(String email, String profileId) {
    setState(() {
      _sharedEmail = email;
      _tabIndex = 0;
      _applyScreenKey++;
    });
    _profileRepository?.saveSelectedProfileId(profileId);
  }

  void _onProfilesUpdated() {
    setState(() => _toolsRefreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading ||
        _profileRepository == null ||
        _historyRepository == null ||
        _settingsRepository == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final dueCount = _historyRepository!.countDueFollowUps();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: IndexedStack(
        index: _tabIndex,
        children: [
          ApplyScreen(
            key: ValueKey('apply-$_applyScreenKey'),
            profileRepository: _profileRepository!,
            historyRepository: _historyRepository!,
            settingsRepository: _settingsRepository!,
            initialEmail: _sharedEmail,
            jobContext: _jobContext,
            onProfilesUpdated: _onProfilesUpdated,
          ),
          ToolsScreen(
            key: ValueKey('tools-$_toolsRefreshKey'),
            profileRepository: _profileRepository!,
            settingsRepository: _settingsRepository!,
            historyRepository: _historyRepository!,
            onProfileUpdated: _onProfilesUpdated,
          ),
          HistoryScreen(
            historyRepository: _historyRepository!,
            onReapply: _reapplyFromHistory,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          boxShadow: [
            BoxShadow(
              color: Color(0x0D0F172A),
              blurRadius: 12,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _tabIndex,
          onDestinationSelected: (index) => setState(() => _tabIndex = index),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.rocket_launch_outlined),
              selectedIcon: Icon(Icons.rocket_launch_rounded),
              label: 'Apply',
            ),
            const NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'Tools',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: dueCount > 0,
                label: Text('$dueCount'),
                child: const Icon(Icons.history_outlined),
              ),
              selectedIcon: const Icon(Icons.history_rounded),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }
}
