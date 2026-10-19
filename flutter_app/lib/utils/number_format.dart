/// German number display and input for ECTS and grades.

/// `5`, `1,5`, `7,25`: decimal comma, no trailing zeros, at most
/// [maxDecimals] places.
String formatDecimal(num value, {int maxDecimals = 2}) {
  var text = value.toStringAsFixed(maxDecimals);
  if (text.contains('.')) {
    text = text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return text.replaceAll('.', ',');
}

/// `1,5` and `1.5` alike; `null` for anything that is not a number.
double? parseDecimal(String text) {
  final normalized = text.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(normalized)) return null;
  return double.parse(normalized);
}

/// ECTS as shown everywhere: `5`, `1,5`.
String formatEcts(num ects) => formatDecimal(ects);

/// Highest ECTS a single lecture may have.
const double maxLectureEcts = 30;

/// Reads an ECTS entry: positive, at most [maxLectureEcts], and in steps of
/// a quarter at the finest (`1,5`, `2,25`), as study regulations use them.
/// Throws a [FormatException] with a message for the user.
double parseLectureEcts(String text) {
  if (text.trim().isEmpty) throw const FormatException('Pflichtfeld');
  final value = parseDecimal(text);
  if (value == null || value <= 0 || value > maxLectureEcts) {
    throw const FormatException('Zahl von 0,25 bis 30, z. B. 5 oder 1,5');
  }
  if ((value * 4).roundToDouble() != value * 4) {
    throw const FormatException('Nur Viertel-Schritte, z. B. 1,5 oder 2,25');
  }
  return value;
}
