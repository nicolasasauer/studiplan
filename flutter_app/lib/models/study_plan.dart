import 'lecture.dart';
import 'semester.dart';

/// Caption for [StudyPlan.targetDelta]: how far the plan is from the target.
String targetDeltaLabel(int delta) {
  if (delta < 0) return 'noch ${-delta} ECTS offen';
  if (delta == 0) return 'Ziel genau erreicht';
  return '$delta ECTS über dem Ziel';
}

class StudyPlan {
  static const defaultPlanName = 'Mein Studienplan';

  String planName;
  int regularSemesters;
  String startSeason; // 'winter' | 'summer'
  bool isConfigured;
  bool weightAverageGradeByEcts;
  /// ECTS the whole degree needs (e.g. 180), or null when not set.
  int? targetEcts;
  List<Semester> semesters;
  List<Lecture> parkingLot;

  StudyPlan({
    this.planName = defaultPlanName,
    this.regularSemesters = 6,
    this.startSeason = 'winter',
    this.isConfigured = false,
    this.weightAverageGradeByEcts = false,
    this.targetEcts,
    List<Semester>? semesters,
    List<Lecture>? parkingLot,
  })  : semesters = semesters ?? [],
        parkingLot = parkingLot ?? [];

  factory StudyPlan.fromJson(Map<String, dynamic> json) {
    final planName = json['planName'] is String &&
            (json['planName'] as String).trim().isNotEmpty
        ? (json['planName'] as String).trim()
        : defaultPlanName;
    final regularSemesters = json['regularSemesters'] is num
        ? (json['regularSemesters'] as num).toInt()
        : 6;
    final startSeason = json['startSeason'] is String &&
            (json['startSeason'] == 'winter' || json['startSeason'] == 'summer')
        ? json['startSeason'] as String
        : 'winter';

    final semesters = (json['semesters'] as List<dynamic>?)
            ?.whereType<Map>()
            .map((s) => Semester.fromJson(Map<String, dynamic>.from(s)))
            .toList() ??
        [];
    final parkingLot = (json['parkingLot'] as List<dynamic>?)
            ?.whereType<Map>()
            .map((l) =>
                Lecture.fromJson(Map<String, dynamic>.from(l)).copyWith(
                  semesterId: null,
                ))
            .toList() ??
        [];
    final inferredConfigured =
        semesters.isNotEmpty || parkingLot.isNotEmpty;

    return StudyPlan(
      planName: planName,
      regularSemesters: regularSemesters,
      startSeason: startSeason,
      isConfigured: json.containsKey('isConfigured')
          ? json['isConfigured'] is bool
              ? json['isConfigured'] as bool
              : inferredConfigured
          : inferredConfigured,
      weightAverageGradeByEcts:
          json['weightAverageGradeByEcts'] is bool
              ? json['weightAverageGradeByEcts'] as bool
              : false,
      targetEcts: normalizeTargetEcts(json['targetEcts']),
      semesters: semesters,
      parkingLot: parkingLot,
    );
  }

  Map<String, dynamic> toJson() => {
        'planName': planName,
        'regularSemesters': regularSemesters,
        'startSeason': startSeason,
        'isConfigured': isConfigured,
        'weightAverageGradeByEcts': weightAverageGradeByEcts,
        // Left out when unset; older app versions ignore the key either way.
        if (targetEcts != null) 'targetEcts': targetEcts,
        'semesters': semesters.map((s) => s.toJson()).toList(),
        'parkingLot': parkingLot.map((l) => l.toJson()).toList(),
      };

  static const maxTargetEcts = 999;

  /// A stored target as a whole number in 1..[maxTargetEcts], else null.
  static int? normalizeTargetEcts(Object? value) {
    if (value is! num || !value.isFinite || value < 1) return null;
    return value.floor().clamp(1, maxTargetEcts);
  }

  /// Parses what the user typed: null for an empty field, the number for a
  /// valid one. Throws [FormatException] with a message for anything else.
  static int? parseTargetEcts(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final value = int.tryParse(trimmed);
    if (value == null || value < 1 || value > maxTargetEcts) {
      throw const FormatException('Bitte eine Zahl von 1 bis 999 eingeben');
    }
    return value;
  }

  /// Planned ECTS minus the target: negative while ECTS are still missing,
  /// positive when more is planned than needed. Null without a target.
  int? get targetDelta => targetEcts == null ? null : totalEcts - targetEcts!;

  bool get isEffectivelyConfigured =>
      isConfigured || semesters.isNotEmpty || parkingLot.isNotEmpty;

  // The parking lot holds modules not planned into any semester yet, so it
  // counts towards none of the totals: not the planned ECTS, not the passed
  // ones and not the grade average.

  int get totalEcts => semesters.fold(0, (s, sem) => s + sem.totalEcts);

  int get passedEcts => semesters.fold(0, (s, sem) => s + sem.passedEcts);

  double? get averageGrade =>
      calculateAverageGrade(weightedByEcts: weightAverageGradeByEcts);

  double? calculateAverageGrade({bool weightedByEcts = false}) {
    final graded = <Lecture>[];
    for (final sem in semesters) {
      graded.addAll(sem.lectures.where((l) => l.passed && l.grade != null));
    }
    if (graded.isEmpty) return null;
    if (!weightedByEcts) {
      return graded.fold(0.0, (sum, lecture) => sum + lecture.grade!) /
          graded.length;
    }

    final totalWeightedEcts =
        graded.fold<int>(0, (sum, lecture) => sum + lecture.ects);
    if (totalWeightedEcts == 0) return null;

    final weightedTotal = graded.fold<double>(
      0.0,
      (sum, lecture) => sum + (lecture.grade! * lecture.ects),
    );
    return weightedTotal / totalWeightedEcts;
  }
}
