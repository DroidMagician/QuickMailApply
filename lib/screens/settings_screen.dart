import 'package:flutter/material.dart';

import '../services/settings_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.repository,
  });

  final SettingsRepository repository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _nameController;
  late int _followUpDays;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.repository.geminiApiKey ?? '');
    _nameController = TextEditingController(text: widget.repository.applicantName);
    _followUpDays = widget.repository.followUpDays;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.repository.saveGeminiApiKey(_apiKeyController.text);
    await widget.repository.saveApplicantName(_nameController.text);
    await widget.repository.saveFollowUpDays(_followUpDays);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'AI Email Generator',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Your name',
                hintText: 'Used in generated emails',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Gemini API key (optional)',
                hintText: 'Get free key at aistudio.google.com',
                border: OutlineInputBorder(),
                helperText: 'Stored locally on device only. Without key, smart templates are used.',
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Follow-up reminders',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'After each Apply, a follow-up reminder is scheduled.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _followUpDays.toDouble(),
                    min: 1,
                    max: 14,
                    divisions: 13,
                    label: '$_followUpDays days',
                    onChanged: (value) => setState(() => _followUpDays = value.round()),
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text('$_followUpDays days'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('Save settings'),
            ),
          ],
        ),
      ),
    );
  }
}
