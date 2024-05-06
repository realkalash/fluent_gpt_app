import 'package:rxdart/rxdart.dart';
import 'dart:developer' as dev;

BehaviorSubject<List<String>> logMessages =
    BehaviorSubject<List<String>>.seeded([]);

void log(String message, [StackTrace? stackTrace]) {
  final value = '${timeStamp()}: $message';
  logMessages.add([...logMessages.value, value]);
  dev.log(value, stackTrace: stackTrace);
  if (logMessages.value.length > 100) {
    logMessages.add(logMessages.value.sublist(1));
  }
}

void logError(String message, [StackTrace? stackTrace]) {
  log('Error: $message', stackTrace);
}

String timeStamp() {
  final now = DateTime.now();
  return '${now.hour}:${now.minute}:${now.second}';
}
