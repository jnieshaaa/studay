import 'dart:math';

class CodeGenerator {
  // Characters for 6-letter exam codes: excluding ambiguous 0/O, 1/I/L
  static const String _codeChars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  static final Random _random = Random.secure();

  /// Generates a readable 6-character exam join code (e.g. "4F9K2Q")
  static String generateExamCode({int length = 6}) {
    final buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      buffer.write(_codeChars[_random.nextInt(_codeChars.length)]);
    }
    return buffer.toString();
  }

  /// Generates a random pseudo-UUID device token for guest participants
  static String generateDeviceToken() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final randPart = _random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return 'dev_${now}_$randPart';
  }

  /// Generates a unique ID for exams/questions
  static String generateId(String prefix) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = _random.nextInt(0xFFFF).toRadixString(16);
    return '${prefix}_${now}_$rand';
  }
}
