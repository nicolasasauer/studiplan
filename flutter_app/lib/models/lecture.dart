import 'package:uuid/uuid.dart';

const _defaultLectureColor = '#4ECDC4';

class Lecture {
  static final _uuid = Uuid();

  final String id;
  String name;
  int ects;
  String? examDate; // YYYY-MM-DD
  String season; // 'winter' | 'summer' | 'both'
  String description;
  String color; // hex, e.g. '#FF6B6B'
  String? semesterId;
  bool passed;
  double? grade;
  bool oralExam;

  Lecture({
    required this.id,
    required this.name,
    required this.ects,
    this.examDate,
    required this.season,
    this.description = '',
    required this.color,
    this.semesterId,
    this.passed = false,
    this.grade,
    this.oralExam = false,
  });

  factory Lecture.fromJson(Map<String, dynamic> json) {
    final id = json['id'] is String && (json['id'] as String).isNotEmpty
        ? json['id'] as String
        : _uuid.v4();
    final name = json['name'] is String && (json['name'] as String).trim().isNotEmpty
        ? (json['name'] as String).trim()
        : 'Unbenannte Veranstaltung';
    final ects = json['ects'] is num ? (json['ects'] as num).toInt() : 0;
    final examDate = json['examDate'] is String && (json['examDate'] as String).isNotEmpty
        ? json['examDate'] as String
        : null;
    final season = json['season'] is String &&
            (json['season'] == 'winter' ||
                json['season'] == 'summer' ||
                json['season'] == 'both')
        ? json['season'] as String
        : 'both';
    final description = json['description'] is String
        ? json['description'] as String
        : '';
    final color = json['color'] is String && (json['color'] as String).isNotEmpty
        ? json['color'] as String
        : _defaultLectureColor;
    final semesterId = json.containsKey('semesterId') &&
            json['semesterId'] is String &&
            (json['semesterId'] as String).isNotEmpty
        ? json['semesterId'] as String
        : null;
    final passed = json['passed'] is bool ? json['passed'] as bool : false;
    final grade = json['grade'] is num ? (json['grade'] as num).toDouble() : null;
    final oralExam = json['oralExam'] is bool ? json['oralExam'] as bool : false;

    return Lecture(
      id: id,
      name: name,
      ects: ects,
      examDate: examDate,
      season: season,
      description: description,
      color: color,
      semesterId: semesterId,
      passed: passed,
      grade: grade,
      oralExam: oralExam,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ects': ects,
        'examDate': examDate,
        'season': season,
        'description': description,
        'color': color,
        'semesterId': semesterId,
        'passed': passed,
        'grade': grade,
        'oralExam': oralExam,
      };

  // Sentinel object used to distinguish "not provided" from null in copyWith
  static const _keep = Object();

  Lecture copyWith({
    String? id,
    String? name,
    int? ects,
    Object? examDate = _keep,
    String? season,
    String? description,
    String? color,
    Object? semesterId = _keep,
    bool? passed,
    Object? grade = _keep,
    bool? oralExam,
  }) =>
      Lecture(
        id: id ?? this.id,
        name: name ?? this.name,
        ects: ects ?? this.ects,
        examDate: examDate == _keep ? this.examDate : examDate as String?,
        season: season ?? this.season,
        description: description ?? this.description,
        color: color ?? this.color,
        semesterId:
            semesterId == _keep ? this.semesterId : semesterId as String?,
        passed: passed ?? this.passed,
        grade: grade == _keep ? this.grade : grade as double?,
        oralExam: oralExam ?? this.oralExam,
      );
}
