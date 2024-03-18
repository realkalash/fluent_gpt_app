import 'package:chatgpt_windows_flutter_app/main.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class OneDriveAccessDialog extends StatelessWidget {
  const OneDriveAccessDialog({super.key});
  static show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const OneDriveAccessDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('OneDrive Access'),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
      content: ListView(
        children: [
          const Text(
            'To upload images you need to sign in with your Microsoft account first.',
          ),
          const Text(
            'To access your OneDrive, you need to sign in with your Microsoft account.',
          ),
          const SizedBox(height: 10.0),
          const MarkdownBody(data: '''
To get a `redirectURL` and `clientID` for OneDrive, you'll need to register your application with Microsoft's Azure Active Directory (Azure AD). Here’s a simplified breakdown of the steps:

1. **Register your application:**
   - Go to the [Azure Portal](https://portal.azure.com/).
   - Navigate to the "Azure Active Directory" service.
   - Select "App registrations" > "New registration".
   - Name your application, choose who can use it, and specify the Redirect URI (the URL where users will be sent after authentication). This Redirect URI is your `redirectURL`.

2. **Get your client ID:**
   - After registering, you'll be directed to your application's overview page.
   - Find the "Application (client) ID" on this page. That's your `clientID`.

3. **Configure permissions:**
   - Still in the Azure Portal, under your application's settings, go to "API permissions".
   - Add the necessary permissions for Microsoft Graph to access OneDrive.

4. **Grant admin consent:**
   - If your app requires access to data that belongs to an organization's users, you might need to ask an administrator to grant consent for your application.

After completing these steps, you'll have both your `redirectURL` and `clientID`, allowing your application to authenticate with Microsoft and access OneDrive through the Microsoft Graph API.
'''),
          const SizedBox(height: 10.0),
          const Text('Enter your `redirectURL`'),
          TextBox(
            onChanged: (value) {
              prefs?.setString('oneDriveRedirectURL', value);
            },
          ),
          const SizedBox(height: 10.0),
          const Text('Enter your `clientID`'),
          TextBox(
            onChanged: (value) {
              prefs?.setString('oneDriveClientID', value);
            },
          ),
        ],
      ),
    );
  }
}
