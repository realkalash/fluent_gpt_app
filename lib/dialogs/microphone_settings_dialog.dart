import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/pages/settings_page.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:record/record.dart';

class MicrophoneSettingsDialog extends StatefulWidget {
  const MicrophoneSettingsDialog({super.key});

  @override
  State<MicrophoneSettingsDialog> createState() =>
      _MicrophoneSettingsDialogState();
}

class _MicrophoneSettingsDialogState extends State<MicrophoneSettingsDialog> {
  List<InputDevice> devices = [
    InputDevice(id: 'null', label: 'Default microphone'),
  ];
  @override
  initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      try {
        devices = await AudioRecorder().listInputDevices();
      } catch (e) {
        logError(e.toString());
      }
     
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Audio and Microphone settings'),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'.tr),
        ),
      ],
      content: ListView(
        shrinkWrap: true,
        children: [
          LabelText('Select microphone'),
          DropDownButton(
            title: AppCache.micrpohoneDeviceId.value == null
                ? const Text('Default microphone')
                : Text(
                    AppCache.micrpohoneDeviceName.value ??
                        'Default microphone',
                  ),
            items: devices
                .map(
                  (e) => MenuFlyoutItem(
                    text: Text(e.label),
                    selected: AppCache.micrpohoneDeviceId.value == e.id,
                    onPressed: () {
                      if (e.id == 'null') {
                        AppCache.micrpohoneDeviceId.remove();
                        AppCache.micrpohoneDeviceName.remove();
                        setState(() {});
                        return;
                      }
                      AppCache.micrpohoneDeviceId.value = e.id;
                      AppCache.micrpohoneDeviceName.value = e.label;
                      setState(() {});
                    },
                  ),
                )
                .toList(),
          ),
          // LabelText('Select Audio output device'),
          // DropDownButton(
          //   title: AppCache.micrpohoneDeviceId.value == null
          //       ? const Text('Default audio output')
          //       : Text(
          //           AppCache.micrpohoneDeviceName.value ??
          //               'Default audio output',
          //         ),
          //   items: outputDevices
          //       .map(
          //         (e) => MenuFlyoutItem(
          //           text: Text(e.label),
          //           selected: AppCache.micrpohoneDeviceId.value == e.id,
          //           onPressed: () {
          //             if (e.id == 'null') {
          //               AppCache.micrpohoneDeviceId.remove();
          //               AppCache.micrpohoneDeviceName.remove();
          //               setState(() {});
          //               return;
          //             }
          //             AppCache.micrpohoneDeviceId.value = e.id;
          //             AppCache.micrpohoneDeviceName.value = e.label;
          //             setState(() {});
          //           },
          //         ),
          //       )
          //       .toList(),
          // ),
        ],
      ),
    );
  }
}
