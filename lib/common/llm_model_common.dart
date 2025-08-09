class LlmModelCommon {
  final String modelName;
  final String modelPath;
  final String modelDescription;
  final String modelUri;
  final bool imageSupported;
  final bool reasoningSupported;
  final bool toolSupported;
  final int? minMemoryUsageBytes;

  const LlmModelCommon({
    required this.modelName,
    required this.modelPath,
    required this.modelDescription,
    required this.modelUri,
    this.imageSupported = false,
    this.reasoningSupported = false,
    this.toolSupported = false,
    this.minMemoryUsageBytes,
  });
}

class LlmModelCommonUtils {
  static List<LlmModelCommon> getModels() {
    return [
      LlmModelCommon(
        modelName: 'Qwen3-1.7B-GGUF',
        modelPath: 'lmstudio-community/Qwen3-1.7B-GGUF:Q6_K',
        modelDescription: """Small model for basic tasks""",
        modelUri: 'https://huggingface.co/Qwen/Qwen3-1.7B',
        imageSupported: false,
        reasoningSupported: false,
        toolSupported: true,
        minMemoryUsageBytes: 1024 * 1024 * 1024 * 1,
      ),
       LlmModelCommon(
        modelName: 'Qwen2.5-7B',
        modelPath: 'lmstudio-community/Qwen3-8B-GGUF:Q4_K_M',
        modelDescription: """Medium model for basic tasks. Great for chat, tasks and everyday use.
Excels at creative writing, role-playing, multi-turn dialogues, and instruction following
        """,
        modelUri: 'https://huggingface.co/Qwen/Qwen3-8B',
        imageSupported: false,
        reasoningSupported: true,
        toolSupported: true,
        minMemoryUsageBytes: 1024 * 1024 * 1024 * 5,
      ),
      LlmModelCommon(
        modelName: 'Qwen3-14B-GGUF',
        modelPath: 'lmstudio-community/Qwen3-14B-GGUF:Q4_K_M',
        modelDescription: 'Large model for complex tasks. Requires more resources to run.',
        modelUri: 'https://huggingface.co/Qwen/Qwen3-14B',
        imageSupported: false,
        reasoningSupported: true,
        toolSupported: true,
        minMemoryUsageBytes: 1024 * 1024 * 1024 * 8,
      ),
      LlmModelCommon(
        modelName: 'gemma-3-12b-it-GGUF',
        modelPath: 'Qwen/Qwen2.5-14B-Instruct-GGUF:Q4_K_M',
        modelDescription: """State-of-the-art image + text input models from Google, built from the same research and tech used to create the Gemini models.
        
Supports a context length of 128k tokens, with a max output of 8192.
Multimodal supporting images normalized to 896 x 896 resolution.
Gemma 3 models are well-suited for a variety of text generation and image understanding tasks, including question answering, summarization, and reasoning.""",
        modelUri: 'https://huggingface.co/lmstudio-community/gemma-3-12b-it-GGUF',
        imageSupported: true,
        reasoningSupported: true,
        toolSupported: true,
      ),
    ];
  }
}