library elevenlabs_flutter;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:elevenlabs_flutter/elevenlabs_config.dart';
import 'package:elevenlabs_flutter/elevenlabs_types.dart';

class ElevenLabsAPI {
  // Singleton instance
  static final ElevenLabsAPI _instance = ElevenLabsAPI._internal();

  factory ElevenLabsAPI() => _instance;

  ElevenLabsAPI._internal();

  // Dio client
  final Dio _dio = Dio();

  /// Initialize API
  /// Takes [baseUrl] and [apiKey] as arguments
  Future<void> init({
    required ElevenLabsConfig config,
  }) async {
    _dio
      ..options.baseUrl = config.baseUrl
      ..options.connectTimeout = const Duration(seconds: 5)
      ..options.receiveTimeout = const Duration(seconds: 45)
      ..options.headers = {
        'Content-Type': 'application/json',
        'xi-api-key': config.apiKey,
      };

    if (Platform.isIOS || Platform.isAndroid) {
      _dio.httpClientAdapter = HttpClientAdapter();
    }
  }

  // Models

  /// Get list of languages
  /// Returns a list of [Language] objects
  Future<List<Language>> getLanguages() async {
    try {
      final response = await _dio.get('/v1/languages');
      return (response.data as List)
          .map((json) => Language.fromJson(json))
          .toList();
    } catch (error) {
      throw _handleError(error);
    }
  }

  // Voices

  /// List available voices
  /// Returns a list of [Voice] objects
  Future<List<Voice>> listVoices() async {
    try {
      final response = await _dio.get('/v1/voices');
      final List<Map<String, dynamic>> responseList =
          List.castFrom(response.data["voices"]);
      final List<Voice> voices = [];
      for (dynamic voiceJson in responseList) {
        voices.add(Voice.fromJson(voiceJson));
      }
      return voices;
    } catch (error) {
      throw _handleError(error);
    }
  }

  /// List available voices raw
  /// Returns a list of [Voice] objects
  Future<List<Map<String, dynamic>>> listVoicesRaw() async {
    try {
      final response = await _dio.get('/v1/voices');
      final List<Map<String, dynamic>> responseList =
          List.castFrom(response.data["voices"]);
      final List<Map<String, dynamic>> voices = [];
      for (dynamic voiceJson in responseList) {
        voices.add(voiceJson);
      }
      return voices;
    } catch (error) {
      throw _handleError(error);
    }
  }

  /// Get default voice settings
  /// Returns a [VoiceSettings] object
  Future<VoiceSettings> getDefaultVoiceSettings() async {
    try {
      final response = await _dio.get('/v1/voices/settings/default');
      return VoiceSettings.fromJson(response.data);
    } catch (error) {
      throw _handleError(error);
    }
  }

  /// Get settings for a voice
  /// Returns a [VoiceSettings] object
  Future<VoiceSettings> getVoiceSettings(String voiceId) async {
    try {
      final response = await _dio.get('/v1/voices/$voiceId/settings');
      return VoiceSettings.fromJson(response.data);
    } catch (error) {
      throw _handleError(error);
    }
  }

  /// Edit settings for a voice
  /// Returns true if successful
  Future<bool> editVoiceSettings(
      String voiceId, double similarityBoost, double stability) async {
    try {
      final response =
          await _dio.post('/v1/voices/$voiceId/settings/edit', data: {
        'similarity_boost': similarityBoost,
        'stability': stability,
      });
      return response.statusCode == 200;
    } catch (error) {
      throw _handleError(error);
    }
  }

  /// Add a new voice
  /// Returns the voice ID
  Future<String> addVoice(AddVoiceRequest request) async {
    try {
      final formData = request.toFormData();
      final response = await _dio.post('/v1/voices/add', data: formData);
      return response.data['voice_id'];
    } catch (error) {
      throw _handleError(error);
    }
  }

  /// Get voice metadata
  /// Returns a [Voice] object
  Future<Voice> getVoice(String voiceId) async {
    try {
      final params = {'with_settings': true};
      final response =
          await _dio.get('/v1/voices/$voiceId', queryParameters: params);
      return Voice.fromJson(response.data);
    } catch (error) {
      throw _handleError(error);
    }
  }

  /// Edit a voice
  /// Returns true if successful
  Future<bool> editVoice(String voiceId, EditVoiceRequest request) async {
    try {
      final formData = request.toFormData();
      await _dio.post('/v1/voices/$voiceId/edit', data: formData);
      return true;
    } catch (error) {
      throw _handleError(error);
    }
  }

  /// Delete a voice
  /// Returns true if successful
  Future<bool> deleteVoice(String voiceId) async {
    try {
      await _dio.delete('/v1/voices/$voiceId');
      return true;
    } catch (error) {
      throw _handleError(error);
    }
  }

  /// Get audio data for a voice sample
  /// Returns a list of bytes
  Future<List<int>> getSampleAudio(String voiceId, String sampleId) async {
    try {
      final response =
          await _dio.get('/v1/voices/$voiceId/samples/$sampleId/audio');
      return response.data;
    } catch (error) {
      throw _handleError(error);
    }
  }

  /// Delete a voice sample
  /// Returns true if successful
  Future<bool> deleteSample(String voiceId, String sampleId) async {
    try {
      await _dio.delete('/v1/voices/$voiceId/samples/$sampleId');
      return true;
    } catch (error) {
      throw _handleError(error);
    }
  }

  // Synthesis

  /// Synthesize text to speech
  /// Takes a [TextToSpeechRequest] object and a value from 0 to 1 on how much to optimize for streaming latency
  /// Returns a [HistoryItem] object
  Future<File> synthesize(TextToSpeechRequest request,
      {int optimizeStreamingLatency = 0}) async {
    try {
      Response<dynamic> response;
      if (optimizeStreamingLatency != 0) {
        response = await _dio.post(
          '/v1/text-to-speech/${request.voiceId}',
          data: request,
          queryParameters: {
            'optimize_streaming_latency': optimizeStreamingLatency
          },
          options: Options(
            responseType: ResponseType.bytes,
          ),
        );
      } else {
        response = await _dio.post(
          '/v1/text-to-speech/${request.voiceId}',
          data: request,
          options: Options(
            responseType: ResponseType.bytes,
          ),
        );
      }

      final localStorage = await Directory.systemTemp.createTemp();
      final String fileName =
          "${localStorage.path}/${request.voiceId}_${DateTime.now().toIso8601String()}.wav";
      final responseFile = await File(fileName).writeAsBytes(response.data);
      return responseFile;
    } catch (error) {
      throw _handleError(error);
    }
  }

  /// Synthesize text to speech
  /// Takes a [TextToSpeechRequest] object and a value from 0 to 1 on how much to optimize for streaming latency
  /// Returns a [HistoryItem] object
  Future<Uint8List> synthesizeBytes(
    TextToSpeechRequest request, {
    int optimizeStreamingLatency = 0,
    required String voiceId,
  }) async {
    try {
      Response<dynamic> response;
      if (optimizeStreamingLatency != 0) {
        response = await _dio.post(
          '/v1/text-to-speech/$voiceId',
          data: request,
          queryParameters: {
            'optimize_streaming_latency': optimizeStreamingLatency
          },
          options: Options(
            responseType: ResponseType.bytes,
          ),
        );
      } else {
        response = await _dio.post(
          '/v1/text-to-speech/$voiceId',
          data: request,
          options: Options(
            responseType: ResponseType.bytes,
          ),
        );
      }
      if (response.data is Uint8List) {
        return response.data;
      }
      throw UnknownApiException(response.data);
    } catch (error) {
      throw _handleError(error);
    }
  }

  // History

  /// Get synthesis history
  /// Returns a list of [HistoryItem] objects
  Future<List<HistoryItem>> getHistory({int pageSize = 100}) async {
    try {
      final params = {'page_size': pageSize};
      final response = await _dio.get('/v1/history', queryParameters: params);
      return (response.data['history'] as List)
          .map((json) => HistoryItem.fromJson(json))
          .toList();
    } catch (error) {
      throw _handleError(error);
    }
  }

  /// Get history item
  /// Returns a [HistoryItem] object
  Future<HistoryItem> getHistoryItem(String historyItemId) async {
    try {
      final response = await _dio.get('/v1/history/$historyItemId');
      return HistoryItem.fromJson(response.data);
    } catch (error) {
      throw _handleError(error);
    }
  }

  /// Get audio data for history item
  /// Returns a list of bytes
  Future<List<int>> getHistoryItemAudio(String historyItemId) async {
    try {
      final response = await _dio.get('/v1/history/$historyItemId/audio');
      return response.data;
    } catch (error) {
      throw _handleError(error);
    }
  }

  /// Delete a history item
  /// Returns true if successful
  Future<bool> deleteHistoryItem(String historyItemId) async {
    try {
      await _dio.delete('/v1/history/$historyItemId');
      return true;
    } catch (error) {
      throw _handleError(error);
    }
  }

  /// Download history items
  /// Returns a list of bytes
  Future<List<int>> downloadHistoryItems(List<String> historyItemIds) async {
    try {
      final response = await _dio.post('/v1/history/download', data: {
        'history_item_ids': historyItemIds,
      });
      return response.data;
    } catch (error) {
      throw _handleError(error);
    }
  }

  // Users

  /// Get current user info
  /// Returns an [ElevenUser] object
  Future<ElevenUser> getCurrentUser() async {
    try {
      final response = await _dio.get('/v1/user');
      return ElevenUser.fromJson(response.data);
    } catch (error) {
      throw _handleError(error);
    }
  }

  /// Get current user info
  /// Returns an [ElevenUser] object
  Future<dynamic> getCurrentUserRaw() async {
    try {
      final response = await _dio.get('/v1/user');
      return response.data;
    } catch (error) {
      throw _handleError(error);
    }
  }

  /// Get current user's subscription info
  /// Returns a [SubscriptionInfo] object
  Future<SubscriptionInfo> getCurrentUserSubscription() async {
    try {
      final response = await _dio.get('/v1/user/subscription');
      return SubscriptionInfo.fromJson(response.data);
    } catch (error) {
      throw _handleError(error);
    }
  }

  // Helper methods

  dynamic _handleError(error) {
    // Handle DioExceptions
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          throw DeadlineExceededException(error.message);
        case DioExceptionType.badResponse:
          switch (error.response?.statusCode) {
            case 400:
              throw BadRequestException(error.response?.data['error']);
            case 401:
              throw UnauthorizedException(error.response?.data['error']);
            case 403:
              throw ForbiddenException(error.response?.data['error']);
            case 404:
              throw NotFoundException(error.response?.data['error']);
            case 409:
              throw ConflictException(error.response?.data['error']);
            case 429:
              throw TooManyRequestsException(error.response?.data['error']);
            case 500:
              throw InternalServerErrorException(error.response?.data['error']);
          }
        case DioExceptionType.cancel:
          throw RequestCanceledException(error.message);
        case DioExceptionType.unknown:
          throw NoInternetConnectionException(error.message);
        default:
          throw UnknownApiException(error);
      }
    }

    // Handle general errors
    throw UnknownApiException(error);
  }
}

// Custom exceptions
class UnknownApiException implements Exception {
  final dynamic error;

  UnknownApiException(this.error);
}

class DeadlineExceededException implements Exception {
  final String? message;

  DeadlineExceededException(this.message);
}

class BadRequestException implements Exception {
  final String? message;

  BadRequestException(this.message);
}

class UnauthorizedException implements Exception {
  final String? message;

  UnauthorizedException(this.message);
}

class ForbiddenException implements Exception {
  final String? message;

  ForbiddenException(this.message);
}

class NotFoundException implements Exception {
  final String? message;

  NotFoundException(this.message);
}

class ConflictException implements Exception {
  final String? message;

  ConflictException(this.message);
}

class TooManyRequestsException implements Exception {
  final String? message;

  TooManyRequestsException(this.message);
}

class InternalServerErrorException implements Exception {
  final String? message;

  InternalServerErrorException(this.message);
}

class RequestCanceledException implements Exception {
  final String? message;

  RequestCanceledException(this.message);
}

class NoInternetConnectionException implements Exception {
  final String? message;

  NoInternetConnectionException(this.message);
}
