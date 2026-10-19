import 'dart:convert';

import '../utils/number_format.dart';
import 'grade_scale.dart';
import 'lecture.dart';
import 'semester.dart';

/// Caption for [StudyPlan.targetDelta]: how far the plan is from the target.
String targetDeltaLabel(num delta) {
  if (delta < 0) return 'noch ${formatEcts(-delta)} ECTS offen';
  if (delta == 0) return 'Ziel genau erreicht';
  return '${formatEcts(delta)} ECTS über dem Ziel';
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

  /// Which grades exist at this university, see [GradeScale].
  GradeScale gradeScale;

  /// Calendar year of the first semester, or null when not set. With it,
  /// every semester gets its term ("WS 2025/26"), which Focus Flow uses to
  /// tell the current one.
  int? startYear;
  List<Semester> semesters;
  List<Lecture> parkingLot;

  StudyPlan({
    this.planName = defaultPlanName,
    this.regularSemesters = 6,
    this.startSeason = 'winter',
    this.isConfigured = false,
    this.weightAverageGradeByEcts = false,
    this.targetEcts,
    this.gradeScale = GradeScale.fallback,
    this.startYear,
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
      gradeScale: GradeScale.fromId(json['gradeScale']),
      startYear: normalizeStartYear(json['startYear']),
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
        'gradeScale': gradeScale.id,
        if (startYear != null) 'startYear': startYear,
        'semesters': semesters.map((s) => s.toJson()).toList(),
        'parkingLot': parkingLot.map((l) => l.toJson()).toList(),
      };

  /// [semester] alone, laid out like a whole plan, for Focus Flow's
  /// "Aus StudiPlan übernehmen". Focus Flow reads it like a full export and
  /// turns the lectures into subjects.
  String semesterExportJson(Semester semester) =>
      const JsonEncoder.withIndent('  ').convert({
        'planName': planName,
        'semesters': [semester.toJson()],
      });

  static const minStartYear = 1990;
  static const maxStartYear = 2100;

  /// A stored start year in [minStartYear]..[maxStartYear], else null.
  static int? normalizeStartYear(Object? value) {
    if (value is! num || !value.isFinite) return null;
    final year = value.floor();
    return year < minStartYear || year > maxStartYear ? null : year;
  }

  /// Parses the typed start year: null for an empty field. Throws
  /// [FormatException] with a message for anything else.
  static int? parseStartYear(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final year = int.tryParse(trimmed);
    if (year == null || year < minStartYear || year > maxStartYear) {
      throw const FormatException('Bitte ein Jahr wie 2025 eingeben');
    }
    return year;
  }

  /// The term of semester [number] - `WS 2025/26`, `SS 2026` - or just
  /// `WS`/`SS` without a [startYear].
  String termLabel(int number, String season) {
    final short = season == 'winter' ? 'WS' : 'SS';
    final term = termOf(number);
    if (term == null) return short;
    if (!term.winter) return '$short ${term.year}';
    final next = '${(term.year + 1) % 100}'.padLeft(2, '0');
    return '$short ${term.year}/$next';
  }

  /// Year and season of semester [number], counted from [startYear] and
  /// [startSeason]; null without a start year. A winter semester carries
  /// the year it starts in.
  ({int year, bool winter})? termOf(int number) {
    final year = startYear;
    if (year == null) return null;
    // Half-years since year 0: summer of Y is 2Y, winter of Y is 2Y + 1.
    final half = 2 * year + (startSeason == 'winter' ? 1 : 0) + number - 1;
    return (year: half ~/ 2, winter: half.isOdd);
  }

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
  double? get targetDelta =>
      targetEcts == null ? null : totalEcts - targetEcts!;

  bool get isEffectivelyConfigured =>
      isConfigured || semesters.isNotEmpty || parkingLot.isNotEmpty;

  // The parking lot holds modules not planned into any semester yet, so it
  // counts towards none of the totals: not the planned ECTS, not the passed
  // ones and not the grade average.

  double get totalEcts =>
      semesters.fold(0.0, (s, sem) => s + sem.totalEcts);

  double get passedEcts =>
      semesters.fold(0.0, (s, sem) => s + sem.passedEcts);

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
        graded.fold<double>(0, (sum, lecture) => sum + lecture.ects);
    if (totalWeightedEcts == 0) return null;

    final weightedTotal = graded.fold<double>(
      0.0,
      (sum, lecture) => sum + (lecture.grade! * lecture.ects),
    );
    return weightedTotal / totalWeightedEcts;
  }
}
