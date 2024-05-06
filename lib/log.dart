import 'package:rxdart/rxdart.dart';
import 'dart:developer' as dev;

BehaviorSubject<List<String>> logMessages =
    BehaviorSubject<List<String>>.seeded([]);

void log(String message) {
  final value = '${timeStamp()}: $message';
  logMessages.add([...logMessages.value, value]);
  dev.log(value);
  if (logMessages.value.length > 100) {
    logMessages.add(logMessages.value.sublist(1));
  }
}

void logError(String message) {
  log('Error: $message');
}

String timeStamp() {
  final now = DateTime.now();
  return '${now.hour}:${now.minute}:${now.second}';
}
