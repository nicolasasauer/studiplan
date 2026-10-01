import 'lecture.dart';

class Semester {
  final String id;
  int number;
  String season; // 'winter' | 'summer'
  List<Lecture> lectures;

  Semester({
    required this.id,
    required this.number,
    required this.season,
    List<Lecture>? lectures,
  }) : lectures = lectures ?? [];

  factory Semester.fromJson(Map<String, dynamic> json) {
    final number = json['number'] is num ? (json['number'] as num).toInt() : 0;
    // Ersatz-ID wie in der Web-App, damit Semester ohne ID nicht alle
    // dieselbe ID bekommen.
    final id = json['id'] is String && (json['id'] as String).isNotEmpty
        ? json['id'] as String
        : 'semester-$number';
    final season = json['season'] is String &&
            (json['season'] == 'winter' || json['season'] == 'summer')
        ? json['season'] as String
        : 'winter';
    final lectures = ((json['lectures'] as List<dynamic>?) ?? const [])
        .whereType<Map>()
        .map((l) {
          final lecture = Lecture.fromJson(Map<String, dynamic>.from(l));
          return lecture.semesterId == id
              ? lecture
              : lecture.copyWith(semesterId: id);
        })
        .toList();

    return Semester(
      id: id,
      number: number,
      season: season,
      lectures: lectures,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'season': season,
        'lectures': lectures.map((l) => l.toJson()).toList(),
      };

  int get totalEcts => lectures.fold(0, (s, l) => s + l.ects);
  int get passedEcts =>
      lectures.where((l) => l.passed).fold(0, (s, l) => s + l.ects);

  double? averageGrade({bool weightedByEcts = false}) {
    final graded = lectures.where((l) => l.passed && l.grade != null).toList();
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
