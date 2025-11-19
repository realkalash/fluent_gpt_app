// From openAi API for testing purposes
const getCurrentWeatherFunction = {
  "type": "function",
  "function": {
    "name": "get_current_weather",
    "description": "Get the current weather in a given location",
    "parameters": {
      "type": "object",
      "properties": {
        "location": {"type": "string", "description": "The city and state, e.g. San Francisco, CA"},
        "unit": {
          "type": "string",
          "enum": ["celsius", "fahrenheit"]
        }
      },
      "required": ["location"]
    }
  }
};
// testing function for pinging
const pingFunction = {
  "type": "function",
  "function": {
    "name": "ping",
    "description": "Ping the server",
    "parameters": {
      "type": "object",
      "properties": {
        "responseMessage": {"type": "string", "description": "The response summary message from chatGPT. Answers only with 'pong' word."}
      },
      "required": ["responseMessage"]
    }
  }
};
@Deprecated('Not used anymore')
const searchFilesFunction = {
  "type": "function",
  "function": {
    "name": "search_files",
    "description":
        "Search for files with a given filename, starting from a specific offset and up to a maximum number of files",
    "parameters": {
      "type": "object",
      "properties": {
        "filename": {"type": "string", "description": "The name of the file to search for"},
        "o": {"type": "integer", "description": "The index to start the search from"},
        "n": {"type": "integer", "description": "The maximum number of files to return in the search results"}
      },
      "required": ["filename", "o", "n"]
    }
  }
};

const writePythonCodeFunction = {
  "type": "function",
  "function": {
    "name": "write_python_code",
    "description": "Generate Python code",
    "parameters": {
      "type": "object",
      "properties": {
        "code": {"type": "string", "description": "The Python code"},
        "responseMessage": {"type": "string", "description": "The response summary message from chatGPT"}
      },
      "required": ["code", "responseMessage"]
    }
  }
};
const copyToClipboardFunction = {
  "type": "function",
  "function": {
    "name": "copy_to_clipboard",
    "description": "Copy the given text to the user's clipboard",
    "parameters": {
      "type": "object",
      "properties": {
        "clipboard": {"type": "string", "description": "Text to copy"},
        "responseMessage": {"type": "string", "description": "The response summary message from chatGPT"}
      },
      "required": ["code", "responseMessage"]
    }
  }
};
const copyToClipboardFunctionParameters = {
  "type": "object",
  "properties": {
    "clipboard": {"type": "string", "description": "Text to copy"},
    "responseMessage": {"type": "string", "description": "The response summary message from chatGPT"}
  },
  "required": ["clipboard", "responseMessage"]
};
const autoOpenUrlParameters = {
  "type": "object",
  "properties": {
    "url": {
      "type": "string",
      "description": "A valid URI with a scheme (e.g., https, tel, whatsapp, mailto, sms, geo)"
    },
    "responseMessage": {"type": "string", "description": "Short response summary message from chatGPT"}
  },
  "required": ["url", "responseMessage"]
};
const generateImageParameters = {
  "type": "object",
  "properties": {
    "prompt": {"type": "string", "description": "A detailed description of the image to generate."},
    "responseMessage": {"type": "string", "description": "Your short response summary message"},
    "size": {
      "type": "string",
      "description": "The size of the image. E.g '1024x1024'. Ensure values are less than 1440. default is 1024x1024"
    },
  },
  "required": ["prompt"]
};
const rememberInfoParameters = {
  "type": "object",
  "properties": {
    "info": {
      "type": "string",
      "description": "A one line summary of the information you want to remember. E.g '{user} likes cats'"
    },
    "responseMessage": {"type": "string", "description": "Your answer to the user. E.g 'Noted' or your own message"}
  },
  "required": ["info", "responseMessage"]
};

const grepChatFunctionParameters = {
  "type": "object",
  "properties": {
    "id": {"type": "string", "description": "The id of the message to grep"},
  },
  "required": ["id"]
};

// Agent-specific tool parameters
const readFileToolParameters = {
  "type": "object",
  "properties": {
    "path": {
      "type": "string",
      "description": "Absolute or relative path to the file to read"
    },
  },
  "required": ["path"]
};

const listDirectoryToolParameters = {
  "type": "object",
  "properties": {
    "path": {
      "type": "string",
      "description": "Absolute or relative path to the directory to list. Use '.' for current directory"
    },
    "recursive": {
      "type": "boolean",
      "description": "Whether to list files recursively in subdirectories. Default is false"
    },
  },
  "required": ["path"]
};

const searchFilesToolParameters = {
  "type": "object",
  "properties": {
    "pattern": {
      "type": "string",
      "description": "Filename pattern to search for (e.g., '*.dart', 'README.md', 'test_*')"
    },
    "directory": {
      "type": "string",
      "description": "Directory to search in. Use '.' for current directory"
    },
    "maxResults": {
      "type": "integer",
      "description": "Maximum number of results to return. Default is 50"
    },
  },
  "required": ["pattern", "directory"]
};

const writeFileToolParameters = {
  "type": "object",
  "properties": {
    "path": {
      "type": "string",
      "description": "Absolute or relative path to the file to write"
    },
    "content": {
      "type": "string",
      "description": "Content to write to the file"
    },
    "append": {
      "type": "boolean",
      "description": "If true, append to file instead of overwriting. Default is false"
    },
  },
  "required": ["path", "content"]
};

const executeShellCommandToolParameters = {
  "type": "object",
  "properties": {
    "command": {
      "type": "string",
      "description": "The shell command to execute (e.g., 'ls -la', 'git status', 'dir')"
    },
    "workingDirectory": {
      "type": "string",
      "description": "Optional working directory to execute command in. Default is current directory"
    },
  },
  "required": ["command"]
};