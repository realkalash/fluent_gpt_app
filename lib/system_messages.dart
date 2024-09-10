String defaultSystemMessage = '';
final shellCommandRegex = RegExp(r'```Shell\n(.*?)\n```', dotAll: true);
final pythonCommandRegex = RegExp(r'```python-exe\n(.*?)\n```', dotAll: true);
final everythingSearchCommandRegex =
    RegExp(r'```Everything-Search\n(.*?)\n```', dotAll: true);
final copyToCliboardRegex = RegExp(r'```Clipboard\n(.*?)\n```', dotAll: true);
final unknownCodeBlockRegex = RegExp(r'```(.*?)\n(.*?)\n```', dotAll: true);

const String nameTopicPrompt =
    'You are an agent to name the chat room topic. Please provide a name in 3-5 words for the chat room based on the following message:';

const String webSearchPrompt =
    'Based on these messages generate a searchPrompt for a google search engine:';
