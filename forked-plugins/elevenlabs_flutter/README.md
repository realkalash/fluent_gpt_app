# elevenlabs_flutter

A Flutter package for interacting with the ElevenLabs API. Provides methods for text-to-speech synthesis, managing voices, and more.
This is the first version of the package, ElevenLabs may update their API, the package may break, I will do my best to keep up with it.

## Installation

Add this to your `pubspec.yaml` file:

```yaml
dependencies:
  elevenlabs_flutter: ^0.1.0
```

or run `dart pub add elevenlabs_flutter`

Then run `dart pub get`.

## Usage

Import the package:

```dart
import 'package:elevenlabs_flutter/elevenlabs_flutter.dart';
```

Create an instance of ElevenLabsAPI:

```dart
final elevenLabs = ElevenLabsAPI();
```

Initialize it with your API key and endpoint:

```dart
await elevenLabs.init(
  baseUrl: 'https://api.elevenlabs.io',
  apiKey: 'YOUR_API_KEY'
);
```

Now you can call methods like:

```dart
// List voices
final voices = await elevenLabs.listVoices();

// Synthesize text  
final result = await elevenLabs.synthesize(
  TextToSpeechRequest(text: 'Hello world!')
);

// Get synthesis history
final history = await elevenLabs.getHistory();
```

See the [API documentation](https://api.elevenlabs.io/docs) for all available methods.

## Handling Errors

Methods can throw custom exceptions, for example:

```dart
try {
  await api.getVoice('voice_id');
} on NotFoundException catch (e) {
  // Handle 404 error
} on UnknownApiException catch (e) {
  // Handle unknown error  
}
```

See code for full list of exceptions.

## Contributing

Pull requests welcome! Feel free to open an issue for any API methods that need implementing.

## License

BSD 3-clause License - see LICENSE for details.