import '../utils/number_format.dart';

/// The grades a university hands out for a passed exam. Picked per plan, so
/// grade input offers exactly these instead of a slider that lands on 2,1.
enum GradeScale {
  /// 1,0 · 1,3 · 1,7 … 4,0.
  germany('de', 'Deutschland', [
    1.0,
    1.3,
    1.7,
    2.0,
    2.3,
    2.7,
    3.0,
    3.3,
    3.7,
    4.0,
  ]),

  /// Whole grades only: 1 (Sehr gut) to 4 (Genügend).
  austria('at', 'Österreich', [1, 2, 3, 4]),

  /// Any grade from 1,0 to 5,0 in tenths, for other scales.
  free('free', 'Frei (Zehntelschritte)', []);

  const GradeScale(this.id, this.label, this.steps);

  /// Stored in the plan JSON as `gradeScale`.
  final String id;
  final String label;

  /// The grades to pick from; empty for [free].
  final List<double> steps;

  static const GradeScale fallback = GradeScale.germany;

  static GradeScale fromId(Object? id) =>
      GradeScale.values.firstWhere((s) => s.id == id, orElse: () => fallback);

  /// Short description for the settings: `1,0 · 1,3 · … · 4,0`.
  String get summary => switch (this) {
    GradeScale.germany => '1,0 · 1,3 · 1,7 · … · 4,0',
    GradeScale.austria => '1 · 2 · 3 · 4 (nur ganze Noten)',
    GradeScale.free => '1,0 bis 5,0 in Zehntelschritten',
  };

  /// A grade as this scale writes it: `2` in Austria, `2,0` elsewhere.
  String format(double grade) =>
      this == GradeScale.austria && grade == grade.roundToDouble()
      ? grade.toStringAsFixed(0)
      : grade.toStringAsFixed(1).replaceAll('.', ',');

  /// Reads a typed grade (`2,3`, `2.3`, `2`). Throws a [FormatException]
  /// with a message for the user when the scale has no such grade.
  double parse(String text) {
    final value = parseDecimal(text);
    if (value == null) {
      throw const FormatException('Bitte eine Note eingeben, z. B. 2,3');
    }
    switch (this) {
      case GradeScale.free:
        if (value < 1 || value > 5 || (value * 10).round() != value * 10) {
          throw const FormatException(
            'Note von 1,0 bis 5,0, eine Nachkommastelle',
          );
        }
        return (value * 10).round() / 10;
      case GradeScale.germany:
      case GradeScale.austria:
        for (final step in steps) {
          if ((step - value).abs() < 0.001) return step;
        }
        throw FormatException(
          'Gibt es in $label nicht. Möglich: '
          '${steps.map(format).join(', ')}',
        );
    }
  }
}

/// Grade averages always get one decimal, whatever the scale: `Ø 2,3`.
String formatAverageGrade(double average) =>
    average.toStringAsFixed(1).replaceAll('.', ',');
