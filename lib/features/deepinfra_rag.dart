import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';

class RAG {
  // Instance version with persistent memory store
  final OpenAIEmbeddings embeddings;
  final MemoryVectorStore vectorStore;
  
  RAG({
    required String apiKey,
    int batchSize = 512,
    int? dimensions,
    String model = 'text-embedding-3-small',
    String? user,
    String baseUrl = 'https://api.openai.com/v1',
  }) : embeddings = OpenAIEmbeddings(
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
  Future<String> getEnhancedPromptWithRag(String query, {int k = 4}) async {
    final retriever = vectorStore.asRetriever(
      defaultOptions: VectorStoreRetrieverOptions(
      searchType: VectorStoreSearchType.similarity,
      
      concurrencyLimit: 5,
      )
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
      searchType: VectorStoreSearchType.similarity,
      k: k,
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
}