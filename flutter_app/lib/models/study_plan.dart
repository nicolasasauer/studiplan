import 'lecture.dart';
import 'semester.dart';

class StudyPlan {
  String planName;
  int regularSemesters;
  String startSeason; // 'winter' | 'summer'
  bool isConfigured;
  bool weightAverageGradeByEcts;
  List<Semester> semesters;
  List<Lecture> parkingLot;

  StudyPlan({
    this.planName = 'Mein Studienplan',
    this.regularSemesters = 6,
    this.startSeason = 'winter',
    this.isConfigured = false,
    this.weightAverageGradeByEcts = false,
    List<Semester>? semesters,
    List<Lecture>? parkingLot,
  })  : semesters = semesters ?? [],
        parkingLot = parkingLot ?? [];

  factory StudyPlan.fromJson(Map<String, dynamic> json) {
    final planName = json['planName'] is String &&
            (json['planName'] as String).trim().isNotEmpty
        ? (json['planName'] as String).trim()
        : 'Mein Studienplan';
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
        'semesters': semesters.map((s) => s.toJson()).toList(),
        'parkingLot': parkingLot.map((l) => l.toJson()).toList(),
      };

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
