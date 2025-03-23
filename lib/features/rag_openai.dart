import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';

class RAGOpenAi {
  // Instance version with persistent memory store
  final OpenAIEmbeddings embeddings;
  final MemoryVectorStore vectorStore;

  RAGOpenAi({
    required String apiKey,
    int batchSize = 512,
    int? dimensions,
    String model = 'text-embedding-3-small',
    String? user,
    String baseUrl = 'https://api.openai.com/v1',
  })  : embeddings = OpenAIEmbeddings(
          apiKey: apiKey,
          batchSize: batchSize,
          user: user,
          model: model,
          baseUrl: baseUrl,
          dimensions: dimensions,
        ),
        vectorStore = MemoryVectorStore(
          embeddings: OpenAIEmbeddings(
            apiKey: apiKey,
            batchSize: batchSize,
            user: user,
            model: model,
            baseUrl: baseUrl,
            dimensions: dimensions,
          ),
        );

  // Method to add documents once
  Future<void> addDocuments(List<Document> documents) async {
    await vectorStore.addDocuments(documents: documents);
  }

  // Method to get enhanced prompt (reusing existing documents)
  Future<String> getEnhancedPromptWithRag(String query,
      {int k = 4, double scoreThreshold = 0.5}) async {
    final retriever = vectorStore.asRetriever(
      defaultOptions: VectorStoreRetrieverOptions(
        searchType: VectorStoreSimilaritySearch(
          k: k,
          scoreThreshold: scoreThreshold,
        ),
      ),
    );

    final relevantDocs = await retriever.getRelevantDocuments(query);

    // Create the enhanced prompt with context
    final context = relevantDocs.map((doc) => doc.pageContent).join('\n\n');

    return '''
Context information:
$context

User question: $query

Answer the question based on the context information provided above.
''';
  }

  // Static version for one-time use
  static Future<String> getEnhancedPromptWithDocs({
    required String query,
    required String apiKey,
    required List<Document> documents,
    int batchSize = 512,
    int? dimensions,
    String model = 'text-embedding-3-small',
    String? user,
    String baseUrl = 'https://api.openai.com/v1',
    int k = 4,
    double scoreThreshold = 0.5,
  }) async {
    final embeddings = OpenAIEmbeddings(
      apiKey: apiKey,
      batchSize: batchSize,
      user: user,
      model: model,
      baseUrl: baseUrl,
      dimensions: dimensions,
    );

    final vectorStore = MemoryVectorStore(embeddings: embeddings);
    await vectorStore.addDocuments(documents: documents);

    final retriever = vectorStore.asRetriever(
      defaultOptions: VectorStoreRetrieverOptions(
        searchType: VectorStoreSimilaritySearch(
          k: k,
          scoreThreshold: scoreThreshold,
        ),
      ),
    );

    final relevantDocs = await retriever.getRelevantDocuments(query);

    // Create the enhanced prompt with context
    var context = relevantDocs.map((doc) => doc.pageContent).join('\n\n');
    if (kDebugMode) {
      log(
        relevantDocs
            .map((doc) =>
                "id: ${doc.id};meta: ${doc.metadata}; cont:${doc.pageContent.length > 4 ? doc.pageContent.substring(0, 4) : doc.pageContent} ")
            .join('\n'),
      );
    }
    if (context.isEmpty) {
      context = 'No relevant documents found.';
    }

    return '''
This is the information you know:
$context
Answer the question ONLY based on the context information provided above.
''';
  }
}
