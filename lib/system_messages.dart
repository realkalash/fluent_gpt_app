String defaultGlobalSystemMessage = 'You are a helpful assistant';
String infoAboutUser = '';
final shellCommandRegex = RegExp(r'```Shell\n(.*?)\n```', dotAll: true);
final pythonCommandRegex = RegExp(r'```python-exe\n(.*?)\n```', dotAll: true);
final everythingSearchCommandRegex =
    RegExp(r'```Everything-Search\n(.*?)\n```', dotAll: true);
final copyToCliboardRegex = RegExp(r'```Clipboard\n(.*?)\n```', dotAll: true);
final unknownCodeBlockRegex = RegExp(r'```(.*?)\n(.*?)\n```', dotAll: true);

const String nameTopicPrompt =
    'You are an agent to name the chat room topic so DONT WRITE ANYTHING EXCEPT CHAT NAME. Please provide a name in 3-5 words for the chat room based on the following messages. Add 1 emoji at the start. Messages:';

const String webSearchPrompt =
    'Based on these messages generate a searchPrompt for a google search engine:';
const String continuePrompt = 'Based on these messages continue the response:';

const String summarizeConversationToRememberUser =
    'Based on these messages summarize the conversation to remember important info about {user}. It should maximum short and max 1-2 sentences. E.g. "Alex is a student". If there is no important info, write "No important info". Messages:';
const String summarizeUserKnowledge =
    'This is knowladge about {user}. Reduce length by summarizing the most important info about {user}. Dont remove any important info. Just reduce lenght. You can remove duplicate items. Info: "{knowledge}"';
