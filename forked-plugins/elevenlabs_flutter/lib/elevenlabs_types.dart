import 'package:json_annotation/json_annotation.dart';
import 'package:dio/dio.dart';

part 'elevenlabs_types.g.dart';

enum StateEnum<String> {
  created,
  deleted,
  processing,
}

/// Text to Speech Request JSON Object
///
/// Used to make API call to convert text to speech
/// Requires text parameter
/// Can optionally pass modelId and voiceSettings
/// See ElevenLabs docs for more info
@JsonSerializable()
class TextToSpeechRequest {
  @JsonKey(name: 'voice_id')
  final String voiceId;
  @JsonKey(name: 'model_id')
  final String? modelId;
  @JsonKey(name: 'text')
  final String text;
  @JsonKey(name: 'voice_settings')
  final VoiceSettings? voiceSettings;

  /// modelId can be "eleven_monolingual_v1"
  TextToSpeechRequest({
    required this.voiceId,
    this.modelId, // 
    required this.text,
    this.voiceSettings,
  });

  factory TextToSpeechRequest.fromJson(Map<String, dynamic> json) =>
      _$TextToSpeechRequestFromJson(json);

  Map<String, dynamic> toJson() => _$TextToSpeechRequestToJson(this);
}

/// Voice Settings JSON Object
///
/// Requires similarity_boost and stability
/// Both values are 0-1.0, recommended settings are .5 and .75
/// Check ElevenLabs Docs for more info
@JsonSerializable()
class VoiceSettings {
  @JsonKey(name: 'similarity_boost')
  final double similarityBoost;

  @JsonKey(name: 'stability')
  final double stability;

  const VoiceSettings({
    required this.similarityBoost,
    required this.stability,
  });

  factory VoiceSettings.fromJson(Map<String, dynamic> json) =>
      _$VoiceSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$VoiceSettingsToJson(this);
}

/// Text to Speech Stream Request JSON Object
///
/// Used to make API call to stream text to speech audio
/// Requires text parameter
/// Can optionally pass modelId and voiceSettings
/// See ElevenLabs docs for more info
@JsonSerializable()
class TextToSpeechStreamRequest {
  @JsonKey(name: 'model_id')
  final String? modelId;
  @JsonKey(name: 'text')
  final String text;
  @JsonKey(name: 'voice_settings')
  final VoiceSettings? voiceSettings;

  TextToSpeechStreamRequest({
    this.modelId,
    required this.text,
    this.voiceSettings,
  });

  factory TextToSpeechStreamRequest.fromJson(Map<String, dynamic> json) =>
      _$TextToSpeechStreamRequestFromJson(json);

  Map<String, dynamic> toJson() => _$TextToSpeechStreamRequestToJson(this);
}

/// Model JSON Object
///
/// Used in /v1/models API response
/// Contains model metadata
/// See ElevenLabs docs for more info
@JsonSerializable()
class ElevenModel {
  @JsonKey(name: 'can_be_finetuned')
  final bool canBeFinetuned;
  @JsonKey(name: 'can_do_text_to_speech')
  final bool canDoTextToSpeech;
  @JsonKey(name: 'can_do_voice_conversion')
  final bool canDoVoiceConversion;
  @JsonKey(name: 'description')
  final String description;
  @JsonKey(name: 'languages')
  final List<Language> languages;
  @JsonKey(name: 'model_id')
  final String modelId;
  @JsonKey(name: 'name')
  final String name;
  @JsonKey(name: 'token_cost_factor')
  final num tokenCostFactor;

  ElevenModel({
    required this.canBeFinetuned,
    required this.canDoTextToSpeech,
    required this.canDoVoiceConversion,
    required this.description,
    required this.languages,
    required this.modelId,
    required this.name,
    required this.tokenCostFactor,
  });

  factory ElevenModel.fromJson(Map<String, dynamic> json) =>
      _$ElevenModelFromJson(json);

  Map<String, dynamic> toJson() => _$ElevenModelToJson(this);
}

/// Language JSON Object
///
/// Nested within Model response
/// Contains language metadata
/// See ElevenLabs docs for more info
@JsonSerializable()
class Language {
  @JsonKey(name: 'language_id')
  final String languageId;
  final String name;

  Language({
    required this.languageId,
    required this.name,
  });

  factory Language.fromJson(Map<String, dynamic> json) =>
      _$LanguageFromJson(json);
  factory Language.fromName(String name) => Language(
        languageId: name.toLowerCase(),
        name: name,
      );

  Map<String, dynamic> toJson() => _$LanguageToJson(this);
}

/// Voice JSON Object
///
/// Returned from /v1/voices endpoints
/// Contains voice metadata
/// See ElevenLabs docs for more info
@JsonSerializable()
class Voice {
  @JsonKey(name: 'available_for_tiers')
  final List<String>? availableForTiers;
  @JsonKey(name: 'category')
  final String category;
  @JsonKey(name: 'description')
  final String? description;
  @JsonKey(name: 'fine_tuning')
  final FineTuning fineTuning;
  @JsonKey(name: 'labels')
  final Labels? labels;
  final String name;
  @JsonKey(name: 'language')
  final String? language;
  @JsonKey(name: 'preview_url')
  final String previewUrl;
  @JsonKey(name: 'samples')
  final List<Sample>? samples;
  @JsonKey(name: 'settings')
  final VoiceSettings? settings;
  @JsonKey(name: 'sharing')
  final Sharing? sharing;
  @JsonKey(name: 'voice_id')
  final String voiceId;

  Voice({
    this.availableForTiers,
    required this.category,
    this.description,
    required this.fineTuning,
    required this.name,
    this.language,
    this.labels,
    required this.previewUrl,
    this.samples,
    this.settings = const VoiceSettings(similarityBoost: 0.5, stability: 0.75),
    this.sharing,
    required this.voiceId,
  });

  factory Voice.fromJson(Map<String, dynamic> json) => _$VoiceFromJson(json);

  Map<String, dynamic> toJson() => _$VoiceToJson(this);
}

enum FineTuningState<String> {
  notStarted,
  isFineTuning,
  fineTuned,
}

/// Fine Tuning JSON Object
///
/// Nested within Voice response
/// Indicates fine tuning status for voice
/// See ElevenLabs docs for more info
@JsonSerializable()
class FineTuning {
  @JsonKey(name: 'fine_tuning_requested')
  final bool? fineTuningRequested;
  @JsonKey(name: 'finetuning_state')
  @FineTuningStateConverter()
  final FineTuningState? fineTuningState;
  @JsonKey(name: 'is_allowed_to_fine_tune')
  final bool isAllowedToFineTune;
  final Language? language;
  @JsonKey(name: 'model_id')
  final String? modelId;
  @JsonKey(name: 'slice_ids')
  final List<String>? sliceIds;
  @JsonKey(name: 'verification_attempts')
  final List<VerificationAttempt>? verificationAttempts;
  @JsonKey(name: 'verification_attempts_count')
  final int verificationAttemptsCount;
  @JsonKey(name: 'verification_failures')
  final List<String> verificationFailures;
  @JsonKey(name: 'manual_verification')
  final bool? manualVerification;

  FineTuning({
    this.fineTuningRequested,
    this.fineTuningState,
    required this.isAllowedToFineTune,
    this.language,
    this.modelId,
    this.sliceIds,
    required this.verificationAttempts,
    required this.verificationAttemptsCount,
    required this.verificationFailures,
    this.manualVerification,
  });

  factory FineTuning.fromJson(Map<String, dynamic> json) =>
      _$FineTuningFromJson(json);

  Map<String, dynamic> toJson() => _$FineTuningToJson(this);
}

class FineTuningStateConverter
    implements JsonConverter<FineTuningState, String> {
  const FineTuningStateConverter();

  @override
  FineTuningState fromJson(String json) {
    switch (json) {
      case 'not_started':
        return FineTuningState.notStarted;
      case 'is_fine_tuning':
        return FineTuningState.isFineTuning;
      case 'fine_tuned':
        return FineTuningState.fineTuned;
      default:
        throw ArgumentError("Invalid fine tuning state: $json");
    }
  }

  @override
  String toJson(FineTuningState object) => object.toString().split('.').last;
}

/// Verification Attempt JSON Object
///
/// Nested within Voice response
/// Contains verification attempt metadata
/// See ElevenLabs docs for more info
@JsonSerializable()
class VerificationAttempt {
  @JsonKey(name: 'date_unix')
  final int dateUnix;
  @JsonKey(name: 'levenshtein_distance')
  final num levenshteinDistance;
  final Recording recording;
  final num similarity;
  final String text;

  VerificationAttempt({
    required this.dateUnix,
    required this.levenshteinDistance,
    required this.recording,
    required this.similarity,
    required this.text,
  });

  factory VerificationAttempt.fromJson(Map<String, dynamic> json) =>
      _$VerificationAttemptFromJson(json);

  Map<String, dynamic> toJson() => _$VerificationAttemptToJson(this);
}

/// Recording JSON Object
///
/// Nested within VerificationAttempt response
/// Contains recording metadata
/// See ElevenLabs docs for more info
@JsonSerializable()
class Recording {
  @JsonKey(name: 'mime_type')
  final String mimeType;
  @JsonKey(name: 'recording_id')
  final String recordingId;
  @JsonKey(name: 'size_bytes')
  final int sizeBytes;
  @JsonKey(name: 'upload_date_unix')
  final int uploadDateUnix;

  Recording({
    required this.mimeType,
    required this.recordingId,
    required this.sizeBytes,
    required this.uploadDateUnix,
  });

  factory Recording.fromJson(Map<String, dynamic> json) =>
      _$RecordingFromJson(json);

  Map<String, dynamic> toJson() => _$RecordingToJson(this);
}

/// Labels JSON Object
///
/// Nested within Voice response
/// Contains voice labels
/// See ElevenLabs docs for more info
@JsonSerializable()
class Labels {
  @JsonKey(name: 'labels')
  final List<String>? labels;

  Labels({
    this.labels,
  });

  factory Labels.fromJson(Map<String, dynamic> json) => _$LabelsFromJson(json);

  Map<String, dynamic> toJson() => _$LabelsToJson(this);
}

/// Sample JSON Object
///
/// Nested within Voice response
/// Contains voice sample metadata
/// See ElevenLabs docs for more info
@JsonSerializable()
class Sample {
  @JsonKey(name: 'file_name')
  final String fileName;
  final String hash;
  @JsonKey(name: 'mime_type')
  final String mimeType;
  @JsonKey(name: 'sample_id')
  final String sampleId;
  @JsonKey(name: 'size_bytes')
  final int sizeBytes;

  Sample({
    required this.fileName,
    required this.hash,
    required this.mimeType,
    required this.sampleId,
    required this.sizeBytes,
  });

  factory Sample.fromJson(Map<String, dynamic> json) => _$SampleFromJson(json);

  Map<String, dynamic> toJson() => _$SampleToJson(this);
}

/// Sharing JSON Object
///
/// Nested within Voice response
/// Contains voice sharing metadata
/// See ElevenLabs docs for more info
@JsonSerializable()
class Sharing {
  @JsonKey(name: 'cloned_by_count')
  final int clonedByCount;
  @JsonKey(name: 'history_item_sample_id')
  final String? historyItemSampleId;
  @JsonKey(name: 'liked_by_count')
  final int likedByCount;
  @JsonKey(name: 'original_voice_id')
  final String originalVoiceId;
  @JsonKey(name: 'public_owner_id')
  final String publicOwnerId;
  final String status;
  @JsonKey(name: 'voice_id')
  final String voiceId;

  Sharing({
    required this.clonedByCount,
    this.historyItemSampleId,
    required this.likedByCount,
    required this.originalVoiceId,
    required this.publicOwnerId,
    required this.status,
    required this.voiceId,
  });

  factory Sharing.fromJson(Map<String, dynamic> json) =>
      _$SharingFromJson(json);

  Map<String, dynamic> toJson() => _$SharingToJson(this);
}

/// Add Voice Request JSON Object
///
/// Used to make /v1/voices/add API request
/// Requires name and files parameters
/// Can optionally pass description and labels
/// See ElevenLabs docs for more info
@JsonSerializable()
class AddVoiceRequest {
  final String? description;
  final List<String> files;
  final String? labels;
  @JsonKey(name: 'name')
  final String name;

  AddVoiceRequest({
    this.description,
    required this.files,
    this.labels,
    required this.name,
  });

  factory AddVoiceRequest.fromJson(Map<String, dynamic> json) =>
      _$AddVoiceRequestFromJson(json);

  Map<String, dynamic> toJson() => _$AddVoiceRequestToJson(this);

  FormData toFormData() {
    FormData data = FormData.fromMap({
      'name': name,
    });

    if (description != null) {
      data.fields.add(MapEntry('description', description!));
    }

    if (labels != null) {
      data.fields.add(MapEntry('labels', labels!));
    }

    for (var file in files) {
      data.files.add(MapEntry(
        'files',
        MultipartFile.fromFileSync(file),
      ));
    }
    return data;
  }
}

/// Add Voice Response JSON Object
///
/// Returned from /v1/voices/add API request
/// Contains new voice ID
/// See ElevenLabs docs for more info
@JsonSerializable()
class AddVoiceResponse {
  @JsonKey(name: 'voice_id')
  final String voiceId;

  AddVoiceResponse({
    required this.voiceId,
  });

  factory AddVoiceResponse.fromJson(Map<String, dynamic> json) =>
      _$AddVoiceResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AddVoiceResponseToJson(this);
}

/// Edit Voice Request JSON Object
///
/// Used to make /v1/voices/{voice_id}/edit API request
/// Requires name parameter
/// Can optionally pass description, files, and labels
/// See ElevenLabs docs for more info
@JsonSerializable()
class EditVoiceRequest {
  final String? description;
  final List<String>? files;
  final String? labels;
  @JsonKey(name: 'name')
  final String name;

  EditVoiceRequest({
    this.description,
    this.files,
    this.labels,
    required this.name,
  });

  factory EditVoiceRequest.fromJson(Map<String, dynamic> json) =>
      _$EditVoiceRequestFromJson(json);

  Map<String, dynamic> toJson() => _$EditVoiceRequestToJson(this);

  FormData toFormData() {
    final formData = FormData();
    formData.fields.add(MapEntry('name', name));
    formData.fields.add(MapEntry('description', description ?? ""));
    formData.fields.add(MapEntry('labels', labels ?? ""));
    if (files != null) {
      for (var file in files!) {
        formData.files.add(MapEntry(
          'files',
          MultipartFile.fromFileSync(file),
        ));
      }
    }
    return formData;
  }
}

/// History JSON Object
///
/// Returned from /v1/history API endpoints
/// Contains history metadata
/// See ElevenLabs docs for more info
@JsonSerializable()
class History {
  @JsonKey(name: 'has_more')
  final bool hasMore;
  final List<HistoryItem> history;
  @JsonKey(name: 'last_history_item_id')
  final String lastHistoryItemId;

  History({
    required this.hasMore,
    required this.history,
    required this.lastHistoryItemId,
  });

  factory History.fromJson(Map<String, dynamic> json) =>
      _$HistoryFromJson(json);

  Map<String, dynamic> toJson() => _$HistoryToJson(this);
}

/// History Item JSON Object
///
/// Nested within History response
/// Contains history item metadata
/// See ElevenLabs docs for more info
@JsonSerializable()
class HistoryItem {
  @JsonKey(name: 'character_count_change_from')
  final int characterCountChangeFrom;
  @JsonKey(name: 'character_count_change_to')
  final int characterCountChangeTo;
  final String contentType;
  @JsonKey(name: 'date_unix')
  final int dateUnix;
  final Feedback feedback;
  @JsonKey(name: 'history_item_id')
  final String historyItemId;
  @JsonKey(name: 'request_id')
  final String requestId;
  final VoiceSettings settings;
  final StateEnum state;
  final String text;
  @JsonKey(name: 'voice_id')
  final String voiceId;
  @JsonKey(name: 'voice_name')
  final String voiceName;

  HistoryItem({
    required this.characterCountChangeFrom,
    required this.characterCountChangeTo,
    required this.contentType,
    required this.dateUnix,
    required this.feedback,
    required this.historyItemId,
    required this.requestId,
    required this.settings,
    required this.state,
    required this.text,
    required this.voiceId,
    required this.voiceName,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) =>
      _$HistoryItemFromJson(json);

  Map<String, dynamic> toJson() => _$HistoryItemToJson(this);
}

/// Feedback JSON Object
///
/// Nested within HistoryItem response
/// Contains feedback metadata
/// See ElevenLabs docs for more info
@JsonSerializable()
class Feedback {
  @JsonKey(name: 'audio_quality')
  final bool audioQuality;
  final bool emotions;
  final String feedback;
  final bool glitches;
  @JsonKey(name: 'inaccurate_clone')
  final bool inaccurateClone;
  final bool other;
  @JsonKey(name: 'review_status')
  final String reviewStatus;
  @JsonKey(name: 'thumbs_up')
  final bool thumbsUp;

  Feedback({
    required this.audioQuality,
    required this.emotions,
    required this.feedback,
    required this.glitches,
    required this.inaccurateClone,
    required this.other,
    required this.reviewStatus,
    required this.thumbsUp,
  });

  factory Feedback.fromJson(Map<String, dynamic> json) =>
      _$FeedbackFromJson(json);

  Map<String, dynamic> toJson() => _$FeedbackToJson(this);
}

/// Download History Items Request JSON Object
///
/// Used to make /v1/history/download API request
/// Requires historyItemIds parameter
/// See ElevenLabs docs for more info
@JsonSerializable()
class DownloadHistoryItemsRequest {
  @JsonKey(name: 'history_item_ids')
  final List<String> historyItemIds;

  DownloadHistoryItemsRequest({
    required this.historyItemIds,
  });

  factory DownloadHistoryItemsRequest.fromJson(Map<String, dynamic> json) =>
      _$DownloadHistoryItemsRequestFromJson(json);

  Map<String, dynamic> toJson() => _$DownloadHistoryItemsRequestToJson(this);
}

/// User JSON Object
///
/// Returned from the /v1/user API Endpoint
/// Contains user metadata and subscription info
@JsonSerializable()
class ElevenUser {
  @JsonKey(name: 'can_use_delayed_payment_methods')
  final bool canUseDelayedPaymentMethods;
  @JsonKey(name: 'is_new_user')
  final bool isNewUser;
  final SubscriptionInfo subscription;
  @JsonKey(name: 'xi_api_key')
  final String xiApiKey;

  ElevenUser({
    required this.canUseDelayedPaymentMethods,
    required this.isNewUser,
    required this.subscription,
    required this.xiApiKey,
  });

  factory ElevenUser.fromJson(Map<String, dynamic> json) =>
      _$ElevenUserFromJson(json);

  Map<String, dynamic> toJson() => _$ElevenUserToJson(this);
}

/// Subscription Info JSON Object
///
/// Returned from /v1/user API endpoints
/// Contains subscription metadata
/// See ElevenLabs docs for more info
@JsonSerializable()
class SubscriptionInfo {
  @JsonKey(name: 'allowed_to_extend_character_limit')
  final bool allowedToExtendCharacterLimit;
  @JsonKey(name: 'can_extend_character_limit')
  final bool canExtendCharacterLimit;
  @JsonKey(name: 'can_extend_voice_limit')
  final bool canExtendVoiceLimit;
  @JsonKey(name: 'can_use_instant_voice_cloning')
  final bool canUseInstantVoiceCloning;
  @JsonKey(name: 'can_use_professional_voice_cloning')
  final bool canUseProfessionalVoiceCloning;
  @JsonKey(name: 'character_count')
  final int characterCount;
  @JsonKey(name: 'character_limit')
  final int characterLimit;
  final String currency;
  @JsonKey(name: 'next_character_count_reset_unix')
  final int nextCharacterCountResetUnix;
  @JsonKey(name: 'professional_voice_limit')
  final int professionalVoiceLimit;
  final String status;
  final String tier;
  @JsonKey(name: 'voice_limit')
  final int voiceLimit;

  SubscriptionInfo({
    required this.allowedToExtendCharacterLimit,
    required this.canExtendCharacterLimit,
    required this.canExtendVoiceLimit,
    required this.canUseInstantVoiceCloning,
    required this.canUseProfessionalVoiceCloning,
    required this.characterCount,
    required this.characterLimit,
    required this.currency,
    required this.nextCharacterCountResetUnix,
    required this.professionalVoiceLimit,
    required this.status,
    required this.tier,
    required this.voiceLimit,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionInfoFromJson(json);

  Map<String, dynamic> toJson() => _$SubscriptionInfoToJson(this);
}

/// Extended Subscription Info JSON Object
///
/// Returned from /v1/user/subscription API endpoint
/// Contains extended subscription metadata
/// See ElevenLabs docs for more info
@JsonSerializable()
class ExtendedSubscriptionInfo {
  @JsonKey(name: 'allowed_to_extend_character_limit')
  final bool allowedToExtendCharacterLimit;
  @JsonKey(name: 'can_extend_character_limit')
  final bool canExtendCharacterLimit;
  @JsonKey(name: 'can_extend_voice_limit')
  final bool canExtendVoiceLimit;
  @JsonKey(name: 'can_use_instant_voice_cloning')
  final bool canUseInstantVoiceCloning;
  @JsonKey(name: 'can_use_professional_voice_cloning')
  final bool canUseProfessionalVoiceCloning;
  @JsonKey(name: 'character_count')
  final int characterCount;
  @JsonKey(name: 'character_limit')
  final int characterLimit;
  final String currency;
  @JsonKey(name: 'has_open_invoices')
  final bool hasOpenInvoices;
  @JsonKey(name: 'next_invoice')
  final NextInvoice nextInvoice;
  @JsonKey(name: 'professional_voice_limit')
  final int professionalVoiceLimit;
  final String status;
  final String tier;
  @JsonKey(name: 'voice_limit')
  final int voiceLimit;

  ExtendedSubscriptionInfo({
    required this.allowedToExtendCharacterLimit,
    required this.canExtendCharacterLimit,
    required this.canExtendVoiceLimit,
    required this.canUseInstantVoiceCloning,
    required this.canUseProfessionalVoiceCloning,
    required this.characterCount,
    required this.characterLimit,
    required this.currency,
    required this.hasOpenInvoices,
    required this.nextInvoice,
    required this.professionalVoiceLimit,
    required this.status,
    required this.tier,
    required this.voiceLimit,
  });

  factory ExtendedSubscriptionInfo.fromJson(Map<String, dynamic> json) =>
      _$ExtendedSubscriptionInfoFromJson(json);

  Map<String, dynamic> toJson() => _$ExtendedSubscriptionInfoToJson(this);
}

/// Next Invoice JSON Object
///
/// Nested within ExtendedSubscriptionInfo response
/// Contains next invoice metadata
/// See ElevenLabs docs for more info
@JsonSerializable()
class NextInvoice {
  @JsonKey(name: 'amount_due_cents')
  final int amountDueCents;
  @JsonKey(name: 'next_payment_attempt_unix')
  final int nextPaymentAttemptUnix;

  NextInvoice({
    required this.amountDueCents,
    required this.nextPaymentAttemptUnix,
  });

  factory NextInvoice.fromJson(Map<String, dynamic> json) =>
      _$NextInvoiceFromJson(json);

  Map<String, dynamic> toJson() => _$NextInvoiceToJson(this);
}
