// From openAi API for testing purposes
const getCurrentWeatherFunction = {
  "type": "function",
  "function": {
    "name": "get_current_weather",
    "description": "Get the current weather in a given location",
    "parameters": {
      "type": "object",
      "properties": {
        "location": {
          "type": "string",
          "description": "The city and state, e.g. San Francisco, CA"
        },
        "unit": {
          "type": "string",
          "enum": ["celsius", "fahrenheit"]
        }
      },
      "required": ["location"]
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
        "filename": {
          "type": "string",
          "description": "The name of the file to search for"
        },
        "o": {
          "type": "integer",
          "description": "The index to start the search from"
        },
        "n": {
          "type": "integer",
          "description":
              "The maximum number of files to return in the search results"
        }
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
        "responseMessage": {
          "type": "string",
          "description": "The response summary message from chatGPT"
        }
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
        "responseMessage": {
          "type": "string",
          "description": "The response summary message from chatGPT"
        }
      },
      "required": ["code", "responseMessage"]
    }
  }
};
const copyToClipboardFunctionParameters = {
  "type": "object",
  "properties": {
    "clipboard": {"type": "string", "description": "Text to copy"},
    "responseMessage": {
      "type": "string",
      "description": "The response summary message from chatGPT"
    }
  },
  "required": ["clipboard", "responseMessage"]
};
const autoOpenUrlParameters = {
  "type": "object",
  "properties": {
    "url": {
      "type": "string",
      "description":
          "A valid URI with a scheme (e.g., https, tel, whatsapp, mailto, sms, geo)"
    },
    "responseMessage": {
      "type": "string",
      "description": "Short response summary message from chatGPT"
    }
  },
  "required": ["url", "responseMessage"]
};
const generateImageParameters = {
  "type": "object",
  "properties": {
    "prompt": {
      "type": "string",
      "description": "A detailed description of the image to generate."
    },
    "responseMessage": {
      "type": "string",
      "description": "Your short response summary message"
    }
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
    "responseMessage": {
      "type": "string",
      "description": "Your answer to the user"
    }
  },
  "required": ["info", "responseMessage"]
};
