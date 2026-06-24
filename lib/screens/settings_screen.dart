import 'package:flutter/material.dart';

import '../services/settings_repository.dart';
import '../services/gmail_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.repository,
    required this.gmailService,
  });

  final SettingsRepository repository;
  final GmailService gmailService;

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
            const SizedBox(height: 28),
            Text(
              'Gmail Account Integration',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Connect your Gmail account to enable direct one-click applying and automatic response tracking.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            _buildGmailSection(),
            const SizedBox(height: 32),
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

  Widget _buildGmailSection() {
    return FutureBuilder<bool>(
      future: widget.gmailService.isSignedIn,
      builder: (context, snapshot) {
        final signedIn = snapshot.data ?? false;
        final email = widget.gmailService.currentUser?.email;

        return Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: signedIn ? Colors.red.shade50 : Colors.grey.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mail_outline_rounded,
                    color: signedIn ? Colors.red : Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        signedIn ? 'Connected to Gmail' : 'Gmail Disconnected',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (signedIn && email != null)
                        Text(
                          email,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                    ],
                  ),
                ),
                if (signedIn)
                  OutlinedButton(
                    onPressed: () async {
                      await widget.gmailService.signOut();
                      setState(() {});
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('Disconnect'),
                  )
                else
                  FilledButton(
                    onPressed: () async {
                      final success = await widget.gmailService.signIn();
                      if (success) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Successfully connected Gmail account')),
                          );
                        }
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to connect Gmail account')),
                          );
                        }
                      }
                      setState(() {});
                    },
                    child: const Text('Connect'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
