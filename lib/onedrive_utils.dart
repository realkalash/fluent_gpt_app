import 'dart:developer';

import 'package:chatgpt_windows_flutter_app/main.dart';
import 'package:cross_file/cross_file.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_onedrive/flutter_onedrive.dart';

class OneDriveUtils {
  OneDrive? oneDrive;
  Future<void> _initDrive(ctx) async {
    if (oneDrive != null) return;
    final clientId = prefs!.getString('oneDriveClientID')!;
    final redirectURL = prefs!.getString('oneDriveRedirectURL')!;
    log('init drive');
    oneDrive = OneDrive(redirectURL: redirectURL, clientID: clientId);
    final res = await oneDrive!.connect(ctx);
    log('Connected to OneDrive: $res');
  }

  Future uploadFile(XFile file, BuildContext ctx) async {
    await _initDrive(ctx);
    log('Uploading file: ${file.name}');
    final res = await oneDrive!
        .push(await file.readAsBytes(), "/fluentgpt_temp_images/${file.name}");
    log('Uploaded file: $res');
  }
}
