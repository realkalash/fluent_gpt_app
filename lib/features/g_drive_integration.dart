import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io';

import 'package:http/http.dart';

/// Class responsible for integrating with Google Drive.
class GDriveIntegration {
  static final _scopes = [drive.DriveApi.driveFileScope];
  static AuthClient? _client;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);

  static Future init() async {
    if (AppCache.useGoogleApi.value!) {
      await authenticate();
    }
  }

  // Method to authenticate the user
  static Future<void> authenticate() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('User cancelled the login');
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final AuthClient client = authenticatedClient(
      Client(),
      AccessCredentials(
        AccessToken('Bearer', googleAuth.accessToken!,
            DateTime.now().add(const Duration(hours: 1))),
        googleAuth.idToken,
        _scopes,
      ),
    );
    _client = client;
    AppCache.useGoogleApi.value = true;
  }

  // Method to upload an image to a temporary folder
  static Future<String> uploadImageToTempFolder(File imageFile) async {
    if (_client == null) {
      throw Exception('User is not authenticated');
    }

    var driveApi = drive.DriveApi(_client!);
    var media = drive.Media(imageFile.openRead(), imageFile.lengthSync());
    var driveFile = drive.File();
    driveFile.name = 'temp_${DateTime.now().millisecondsSinceEpoch}.jpg';
    driveFile.parents = ['appDataFolder'];

    var result = await driveApi.files.create(driveFile, uploadMedia: media);
    return result.id!;
  }
}
