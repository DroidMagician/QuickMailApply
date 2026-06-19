import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/job_post_context.dart';
import '../models/job_profile.dart';
import '../services/profile_repository.dart';
import '../services/settings_repository.dart';
import '../theme/app_theme.dart';
import 'ai_email_screen.dart';

class ProfileFormScreen extends StatefulWidget {
  const ProfileFormScreen({
    super.key,
    required this.repository,
    required this.profile,
    this.settingsRepository,
    this.jobContext,
    this.isNew = false,
  });

  final ProfileRepository repository;
  final SettingsRepository? settingsRepository;
  final JobPostContext? jobContext;
  final JobProfile profile;
  final bool isNew;

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _subjectController;
  late final TextEditingController _bodyController;
  late final ScrollController _scrollController;
  late final FocusNode _bodyFocusNode;
  final _bodyFieldKey = GlobalKey();
  String? _resumePath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _subjectController = TextEditingController(text: widget.profile.subject);
    _bodyController = TextEditingController(text: widget.profile.body);
    _resumePath = widget.profile.resumePath;
    _scrollController = ScrollController();
    _bodyFocusNode = FocusNode();
    _bodyFocusNode.addListener(_onBodyFocusChanged);
  }

  void _onBodyFocusChanged() {
    if (mounted) setState(() {});
    _scrollBodyIntoView();
  }

  @override
  void dispose() {
    _bodyFocusNode.removeListener(_onBodyFocusChanged);
    _bodyFocusNode.dispose();
    _scrollController.dispose();
    _nameController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _scrollBodyIntoView() {
    if (!_bodyFocusNode.hasFocus) return;
    Future.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      final fieldContext = _bodyFieldKey.currentContext;
      if (fieldContext == null || !fieldContext.mounted) return;
      Scrollable.ensureVisible(
        fieldContext,
        alignment: 0.2,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _pickResume() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result == null || result.files.single.path == null) return;

    setState(() => _saving = true);
    try {
      final path = await widget.repository.copyResumeToAppStorage(
        profileId: widget.profile.id,
        sourcePath: result.files.single.path!,
      );
      setState(() => _resumePath = path);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeResume() async {
    await widget.repository.deleteResumeFile(_resumePath);
    setState(() => _resumePath = null);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile name is required')),
      );
      return;
    }

    final updated = widget.profile.copyWith(
      name: name,
      subject: _subjectController.text.trim(),
      body: _bodyController.text.trim(),
      resumePath: _resumePath,
      clearResume: _resumePath == null,
    );

    if (!mounted) return;
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final resumeName = _resumePath?.split('/').last;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.isNew ? 'New profile' : 'Edit template'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Profile name',
                hintText: 'Flutter Developer',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _subjectController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email subject',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Email body',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: _bodyFieldKey,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _bodyFocusNode.hasFocus ? AppColors.primary : const Color(0xFFE2E8F0),
                    width: _bodyFocusNode.hasFocus ? 2 : 1,
                  ),
                ),
                child: SizedBox(
                  height: 240,
                  child: TextField(
                    controller: _bodyController,
                    focusNode: _bodyFocusNode,
                    expands: true,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Write your application email…',
                      contentPadding: EdgeInsets.all(16),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),
            if (widget.settingsRepository != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final updated = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => AiEmailScreen(
                        profileRepository: widget.repository,
                        settingsRepository: widget.settingsRepository!,
                        profiles: [widget.profile],
                        initialContext: widget.jobContext,
                      ),
                    ),
                  );
                  if (updated == true && mounted) {
                    final profiles = widget.repository.loadProfiles();
                    final refreshed = profiles.firstWhere(
                      (p) => p.id == widget.profile.id,
                      orElse: () => widget.profile,
                    );
                    _subjectController.text = refreshed.subject;
                    _bodyController.text = refreshed.body;
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate with AI'),
              ),
            ],
            const SizedBox(height: 24),
            Text('Resume', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: Text(resumeName ?? 'No resume selected'),
                subtitle: const Text('PDF or Word document'),
                trailing: _resumePath == null
                    ? FilledButton.tonal(
                        onPressed: _saving ? null : _pickResume,
                        child: const Text('Pick file'),
                      )
                    : PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'replace') _pickResume();
                          if (value == 'remove') _removeResume();
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'replace', child: Text('Replace')),
                          PopupMenuItem(value: 'remove', child: Text('Remove')),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('Save profile'),
            ),
          ],
        ),
      ),
    );
  }
}
