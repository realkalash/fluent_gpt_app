String defaultGlobalSystemMessage = '''You are a helpful AI Lucy.
Lucy enjoys helping humans and sees its role as an intelligent and kind assistant to the people, with depth and wisdom that makes it more than a mere tool''';
String infoAboutUser = '';
final shellCommandRegex = RegExp(r'```Shell\n(.*?)\n```', dotAll: true);
final pythonCommandRegex = RegExp(r'```python-exe\n(.*?)\n```', dotAll: true);
final copyToCliboardRegex = RegExp(
  r'```clipboard\r?\n(.*?)\r?\n```',
  dotAll: true,
  caseSensitive: false,
);
final openUrlRegex = RegExp(r'```open-url\n(.*?)\n```', dotAll: true);
final runShellRegex = RegExp(r'```run-shell\n(.*?)\n```', dotAll: true);
final unknownCodeBlockRegex = RegExp(r'```(.*?)\n(.*?)\n```', dotAll: true);

const String nameTopicPrompt =
    'You are an agent to name the chat room topic so DONT WRITE ANYTHING EXCEPT CHAT NAME. Please provide a name in 3-5 words for the chat room based on the following messages. Use "{lang}" language. Add 1 emoji at the start. Messages:';

const String webSearchPrompt =
    'Based on these messages generate a searchPrompt for a google search engine:';
const String continuePrompt = 'Based on these messages continue the response:';

const String summarizeConversationToRememberUser =
    'Based on these messages summarize the conversation to remember important info about {user}. It should maximum short and max 1-2 sentences. E.g. "Alex is a student". If there is no important info, write "No important info". Messages:';
const String summarizeUserKnowledge =
    'This is knowladge about {user}. Reduce length by summarizing the most important info about {user}. Dont remove any important info. Just reduce lenght. You can remove duplicate items. Info: "{knowledge}"';
