import 'package:chatgpt_windows_flutter_app/common/prefs/prefs_types.dart';

class AppCache {
  static const currentFileIndex = IntPref("currentFileIndex");
  // ${resolution.width}x${resolution.height}
  static const resolution = StringPref("resolution");
  static const preventClose = BoolPref("preventClose");
  static const showAppInDock = BoolPref("showAppInDock", true);
  static const windowX = IntPref("windowX");
  static const windowY = IntPref("windowY");
  static const windowWidth = IntPref("windowWidth");
  static const windowHeight = IntPref("windowHeight");
  static const chatRooms = StringPref("chatRooms");
  static const selectedChatRoomName = StringPref("selectedChatRoomName");
  static const token = StringPref("token");
  static const orgID = StringPref("orgID");
  static const llmUrl = StringPref("llmUrl");
  static const tokensUsedTotal = IntPref("tokensUsedTotal");
  static const costTotal = DoublePref("costTotal");

  static const gptToolSearchEnabled = BoolPref("gptToolSearchEnabled", true);
  static const gptToolPythonEnabled = BoolPref("gptToolPythonEnabled", true);
}
