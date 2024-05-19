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
