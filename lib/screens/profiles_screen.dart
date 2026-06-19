import 'package:flutter/material.dart';

import '../models/job_profile.dart';
import '../services/profile_repository.dart';
import 'profile_form_screen.dart';

class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({
    super.key,
    required this.repository,
    required this.profiles,
  });

  final ProfileRepository repository;
  final List<JobProfile> profiles;

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  late List<JobProfile> _profiles;

  @override
  void initState() {
    super.initState();
    _profiles = List.of(widget.profiles);
  }

  Future<void> _persist() async {
    await widget.repository.saveProfiles(_profiles);
  }

  Future<void> _addProfile() async {
    final draft = widget.repository.createProfile(name: 'New Profile');
    final created = await Navigator.of(context).push<JobProfile>(
      MaterialPageRoute(
        builder: (_) => ProfileFormScreen(
          repository: widget.repository,
          profile: draft,
          isNew: true,
        ),
      ),
    );

    if (created != null) {
      setState(() => _profiles.add(created));
      await _persist();
    }
  }

  Future<void> _editProfile(JobProfile profile) async {
    final updated = await Navigator.of(context).push<JobProfile>(
      MaterialPageRoute(
        builder: (_) => ProfileFormScreen(repository: widget.repository, profile: profile),
      ),
    );

    if (updated != null) {
      final index = _profiles.indexWhere((item) => item.id == updated.id);
      if (index != -1) {
        setState(() => _profiles[index] = updated);
        await _persist();
      }
    }
  }

  Future<void> _deleteProfile(JobProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete profile?'),
        content: Text('Remove "${profile.name}" and its saved resume?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true) return;

    await widget.repository.deleteResumeFile(profile.resumePath);
    setState(() => _profiles.removeWhere((item) => item.id == profile.id));
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_profiles);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profiles'),
          leading: BackButton(onPressed: () => Navigator.of(context).pop(_profiles)),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addProfile,
          icon: const Icon(Icons.add),
          label: const Text('Add profile'),
        ),
        body: _profiles.isEmpty
            ? const Center(child: Text('No profiles yet. Tap Add profile.'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: _profiles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final profile = _profiles[index];
                  return Card(
                    child: ListTile(
                      title: Text(profile.name),
                      subtitle: Text(
                        profile.hasResume
                            ? '${profile.subject}\nResume: ${profile.resumeFileName}'
                            : profile.subject,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      onTap: () => _editProfile(profile),
                      trailing: IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteProfile(profile),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
