import 'dart:io';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_ui/fluent_ui.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
  });

  static Future<void> show(BuildContext context, UpdateInfo updateInfo) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateDialog(updateInfo: updateInfo),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog>
    with TickerProviderStateMixin {
  bool _isDownloading = false;
  bool _isInstalling = false;
  double _downloadProgress = 0.0;
  String _statusText = '';

  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
      title: Row(
        children: [
          Icon(
            FluentIcons.update_restore,
            color: theme.accentColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            'Update Available'.tr,
            style: theme.typography.title,
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Version info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.accentColor.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.accentColor.withAlpha(75),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        FluentIcons.package,
                        color: theme.accentColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${'New Version'.tr}: ${widget.updateInfo.version}',
                        style: theme.typography.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${'Size'.tr}: ${_formatFileSize(widget.updateInfo.downloadSize)}',
                    style: theme.typography.body,
                  ),
                  Text(
                    '${'Published'.tr}: ${_formatDate(widget.updateInfo.publishedAt)}',
                    style: theme.typography.body,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Release notes
            if (widget.updateInfo.releaseNotes.isNotEmpty) ...[
              Text(
                'What\'s New:',
                style: theme.typography.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.micaBackgroundColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: theme.resources.dividerStrokeColorDefault,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.updateInfo.releaseNotes,
                    style: theme.typography.body,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Progress section
            if (_isDownloading || _isInstalling) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.resources.dividerStrokeColorDefault,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: ProgressRing(
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _statusText,
                            style: theme.typography.body,
                          ),
                        ),
                      ],
                    ),
                    if (_isDownloading) ...[
                      const SizedBox(height: 12),
                      ProgressBar(
                        value: _downloadProgress * 100,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                        style: theme.typography.caption,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isDownloading && !_isInstalling) ...[
          Button(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Later'.tr),
          ),
          FilledButton(
            onPressed: () =>
                UpdateService.instance.downloadLatestRelease(widget.updateInfo),
            child: Text('Download Manually'.tr),
          ),
          // TODO: add macOS/linux support
          if (Platform.isWindows)
            FilledButton(
              onPressed: () => _downloadAndInstall(),
              child: Text('Install Now'.tr),
            ),
        ] else ...[
          Button(
            onPressed: _isInstalling ? null : () => Navigator.of(context).pop(),
            child: Text('Cancel'.tr),
          ),
        ],
      ],
    );
  }

  Future<void> _downloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _statusText = 'Downloading update...'.tr;
      _downloadProgress = 0.0;
    });

    try {
      // Download the update
      final filePath = await UpdateService.instance.downloadUpdate(
        widget.updateInfo,
        onProgress: (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
      );

      if (filePath == null) {
        throw Exception('${'Download failed'.tr}. Empty file');
      }

      setState(() {
        _isDownloading = false;
        _isInstalling = true;
        _statusText = 'Installing update...'.tr;
      });

      // Install the update
      final success = await UpdateService.instance.installUpdate(filePath);

      if (success) {
        _showSuccessDialog();
      } else {
        throw Exception('Installation failed'.tr);
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _isInstalling = false;
      });

      _showErrorDialog(e.toString());
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Text('Update Installed'.tr),
        content: Text(
          'The update has been installed successfully. Please restart the application to use the new version.'
              .tr,
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close success dialog
              Navigator.of(context).pop(); // Close update dialog
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Row(
          children: [
            Icon(
              FluentIcons.error,
              color: Colors.red,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text('Update Failed'.tr),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The automatic update failed. You can:'.tr),
            const SizedBox(height: 12),
            Text('• Download manually from GitHub'.tr),
            Text('• Try again later'.tr),
            const SizedBox(height: 12),
            Text(
              'Error: $error',
              style: FluentTheme.of(context).typography.caption,
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'.tr),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              UpdateService.instance.downloadLatestRelease(widget.updateInfo);
            },
            child: Text('Download Manually'.tr),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today'.tr;
      } else if (difference.inDays == 1) {
        return 'Yesterday'.tr;
      } else if (difference.inDays < 7) {
        return '${difference.inDays} ${'days ago'.tr}';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateString;
    }
  }
}
