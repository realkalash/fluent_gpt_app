import 'package:fluent_ui/fluent_ui.dart';
import '../services/update_manager.dart';
import '../services/update_service.dart';

class UpdateSettingsWidget extends StatefulWidget {
  const UpdateSettingsWidget({super.key});

  @override
  State<UpdateSettingsWidget> createState() => _UpdateSettingsWidgetState();
}

class _UpdateSettingsWidgetState extends State<UpdateSettingsWidget> {
  Map<String, dynamic> _settings = {};
  bool _isLoading = true;
  bool _isCheckingForUpdates = false;
  String _currentVersion = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadCurrentVersion();
  }

  Future<void> _loadSettings() async {
    final settings = await UpdateManager.instance.getSettings();
    setState(() {
      _settings = settings;
      _isLoading = false;
    });
  }

  Future<void> _loadCurrentVersion() async {
    final version = await UpdateService.instance.getCurrentVersion();
    setState(() {
      _currentVersion = version;
    });
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    setState(() {
      _settings[key] = value;
    });

    switch (key) {
      case 'autoCheckEnabled':
        await UpdateManager.instance.updateSettings(autoCheckEnabled: value);
        break;
      case 'checkIntervalHours':
        await UpdateManager.instance.updateSettings(checkIntervalHours: value);
        break;
      case 'notifyOnStartup':
        await UpdateManager.instance.updateSettings(notifyOnStartup: value);
        break;
    }
  }

  Future<void> _checkForUpdatesNow() async {
    setState(() {
      _isCheckingForUpdates = true;
    });

    try {
      await UpdateManager.instance.checkForUpdatesNow(silent: false);
    } finally {
      setState(() {
        _isCheckingForUpdates = false;
      });
    }
  }

  Future<void> _clearSkippedVersion() async {
    await UpdateManager.instance.clearSkippedVersion();
    await _loadSettings();
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('Skipped Version Cleared'),
          content: const Text('Previously skipped version has been cleared. You will be notified of all future updates.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Never';
    
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes} minutes ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours} hours ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    if (_isLoading) {
      return const Center(
        child: ProgressRing(),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                FluentIcons.update_restore,
                color: theme.accentColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'App Updates',
                style: theme.typography.title,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Current version info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: theme.accentColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  FluentIcons.info,
                  color: theme.accentColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current Version: $_currentVersion',
                  style: theme.typography.body?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Button(
                  onPressed: _isCheckingForUpdates ? null : _checkForUpdatesNow,
                  child: _isCheckingForUpdates
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: ProgressRing(strokeWidth: 1.5),
                            ),
                            const SizedBox(width: 8),
                            const Text('Checking...'),
                          ],
                        )
                      : const Text('Check Now'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Auto-check setting
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Automatic Updates',
                      style: theme.typography.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Automatically check for updates in the background',
                      style: theme.typography.caption,
                    ),
                  ],
                ),
              ),
              ToggleSwitch(
                checked: _settings['autoCheckEnabled'] ?? true,
                onChanged: (value) => _updateSetting('autoCheckEnabled', value),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Check interval setting
          if (_settings['autoCheckEnabled'] == true) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Check Interval',
                        style: theme.typography.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'How often to check for updates',
                        style: theme.typography.caption,
                      ),
                    ],
                  ),
                ),
                ComboBox<int>(
                  value: _settings['checkIntervalHours'] ?? 24,
                  onChanged: (value) {
                    if (value != null) {
                      _updateSetting('checkIntervalHours', value);
                    }
                  },
                  items: [
                    ComboBoxItem(value: 1, child: Text('Every hour')),
                    ComboBoxItem(value: 6, child: Text('Every 6 hours')),
                    ComboBoxItem(value: 12, child: Text('Every 12 hours')),
                    ComboBoxItem(value: 24, child: Text('Daily')),
                    ComboBoxItem(value: 168, child: Text('Weekly')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Startup notification setting
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notify on Startup',
                      style: theme.typography.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Check for updates when the app starts',
                      style: theme.typography.caption,
                    ),
                  ],
                ),
              ),
              ToggleSwitch(
                checked: _settings['notifyOnStartup'] ?? true,
                onChanged: (value) => _updateSetting('notifyOnStartup', value),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Status information
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.micaBackgroundColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: theme.resources.dividerStrokeColorDefault,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update Status',
                  style: theme.typography.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Text(
                      'Last Check: ',
                      style: theme.typography.body,
                    ),
                    Text(
                      _formatDate(_settings['lastCheckTime']),
                      style: theme.typography.body?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                if (_settings['skippedVersion'] != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Skipped Version: ',
                        style: theme.typography.body,
                      ),
                      Text(
                        _settings['skippedVersion'],
                        style: theme.typography.body?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      HyperlinkButton(
                        onPressed: _clearSkippedVersion,
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Information note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.accentColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: theme.accentColor.withOpacity(0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  FluentIcons.info,
                  color: theme.accentColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update Information',
                        style: theme.typography.body?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Updates are downloaded from GitHub releases\n'
                        '• You can choose to install automatically or manually\n'
                        '• All updates are digitally signed for security\n'
                        '• No personal data is sent during update checks',
                        style: theme.typography.caption,
                      ),
                    ],
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