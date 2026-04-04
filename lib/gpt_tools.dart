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
        "responseMessage": {
          "type": "string",
          "description": "The response summary message from chatGPT. Answers only with 'pong' word."
        }
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
const copyToClipboardFunctionParameters = {
  "type": "object",
  "properties": {
    "clipboard": {"type": "string", "description": "Text to copy"},
    // "responseMessage": {"type": "string", "description": "The response summary message from chatGPT"}
  },
  "required": ["clipboard"]
};
const autoOpenUrlParameters = {
  "type": "object",
  "properties": {
    "url": {
      "type": "string",
      "description": "A valid URI with a scheme (e.g., https, tel, whatsapp, mailto, sms, geo)"
    },
    // "responseMessage": {"type": "string", "description": "Short response summary message from chatGPT"}
  },
  "required": [
    "url",
    // "responseMessage",
  ]
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
    "path": {"type": "string", "description": "Absolute or relative path to the file to read"},
    "offset": {
      "type": "integer",
      "description":
          "1-based line number to start from. Negative counts from end of file (-1 = last line). Omit to start at line 1"
    },
    "limit": {
      "type": "integer",
      "description":
          "Maximum number of lines to return. If omitted with offset omitted, only the first ~500 lines are returned for large files to save tokens; pass a limit to read more in chunks"
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
    "glob": {
      "type": "string",
      "description":
          "Optional filename glob using * and ? only (e.g. '*.dart', '*.ipa'). When set, only file paths whose basename matches are listed"
    },
    "entries": {
      "type": "string",
      "enum": ["all", "files", "directories"],
      "description": "Return only files, only directories, or both. Default is all"
    },
    "exclude": {
      "type": "array",
      "items": {"type": "string"},
      "description":
          "Basenames to skip anywhere in the path (e.g. '.git', 'node_modules', 'build'). Added on top of skipCommonIgnored when true"
    },
    "skipCommonIgnored": {
      "type": "boolean",
      "description":
          "If true (default), skip common heavy folders like .git, node_modules, .dart_tool, build, dist, Pods, DerivedData"
    },
  },
  "required": ["path"]
};

const searchFilesToolParameters = {
  "type": "object",
  "properties": {
    "pattern": {
      "type": "string",
      "description": "Filename pattern to search for (e.g., '*.dart', 'README.md', 'test_*'). Uses * and ? wildcards only"
    },
    "directory": {"type": "string", "description": "Directory to search in. Use '.' for current directory"},
    "maxResults": {"type": "integer", "description": "Maximum number of results to return. Default is 50"},
    "skipCommonIgnored": {
      "type": "boolean",
      "description": "If true (default), skip common heavy directories (.git, node_modules, build, etc.) while walking the tree"
    },
  },
  "required": ["pattern", "directory"]
};

const grepToolParameters = {
  "type": "object",
  "properties": {
    "pattern": {
      "type": "string",
      "description":
          "Regular expression to search for inside file contents (ripgrep/Rust regex when ripgrep is available; Dart RegExp in fallback). Escape special characters if you need a literal match"
    },
    "path": {
      "type": "string",
      "description": "File or directory to search under. Use '.' for current directory. Default '.'"
    },
    "glob": {
      "type": "string",
      "description": "Only search files whose path matches this glob (e.g. '*.dart'). Passed to ripgrep when available"
    },
    "max_results": {
      "type": "integer",
      "description": "Maximum number of matching lines (output lines) to return. Default 80"
    },
    "context_lines": {
      "type": "integer",
      "description": "Lines of context before/after each match when using ripgrep. Default 2; use 0 for matches only"
    },
    "case_sensitive": {"type": "boolean", "description": "If false, search is case-insensitive. Default true"},
    "skipCommonIgnored": {
      "type": "boolean",
      "description": "Dart fallback only: skip .git, node_modules, build, etc. Default true"
    },
  },
  "required": ["pattern"]
};

const editFileToolParameters = {
  "type": "object",
  "properties": {
    "path": {"type": "string", "description": "Path to the existing file to edit"},
    "old_string": {
      "type": "string",
      "description":
          "Exact contiguous text to replace; must appear exactly once in the file. Include several lines of surrounding context so it is unique"
    },
    "new_string": {"type": "string", "description": "Replacement text (may be empty to delete old_string)"},
  },
  "required": ["path", "old_string", "new_string"]
};

const writeFileToolParameters = {
  "type": "object",
  "properties": {
    "path": {"type": "string", "description": "Absolute or relative path to the file to write"},
    "content": {"type": "string", "description": "Full content to write to the file"},
    "append": {"type": "boolean", "description": "If true, append to file instead of overwriting. Default is false"},
  },
  "required": ["path", "content"]
};

const executeShellCommandToolParameters = {
  "type": "object",
  "properties": {
    "command": {"type": "string", "description": "The shell command to execute (e.g., 'ls -la', 'git status', 'dir')"},
    "workingDirectory": {
      "type": "string",
      "description": "Optional working directory to execute command in. Default is current directory"
    },
  },
  "required": ["command"]
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