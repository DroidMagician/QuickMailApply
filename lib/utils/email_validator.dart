bool isValidEmail(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  final pattern = RegExp(r'^[\w.\+-]+@[\w.-]+\.[a-zA-Z]{2,}$');
  return pattern.hasMatch(trimmed);
}

String? extractEmailFromText(String text) {
  final pattern = RegExp(r'[\w.\+-]+@[\w.-]+\.[a-zA-Z]{2,}');
  final match = pattern.firstMatch(text.trim());
  return match?.group(0);
}
