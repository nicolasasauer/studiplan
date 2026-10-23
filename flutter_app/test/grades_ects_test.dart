import 'package:flutter_test/flutter_test.dart';
import 'package:studi_plan/models/grade_scale.dart';
import 'package:studi_plan/models/lecture.dart';
import 'package:studi_plan/models/semester.dart';
import 'package:studi_plan/models/study_plan.dart';
import 'package:studi_plan/utils/number_format.dart';

Lecture _lecture(String name, double ects, {double? grade}) => Lecture(
      id: name,
      name: name,
      ects: ects,
      season: 'both',
      color: '#4ECDC4',
      passed: grade != null,
      grade: grade,
    );

void main() {
  group('ECTS', () {
    test('format with a comma and without trailing zeros', () {
      expect(formatEcts(5), '5');
      expect(formatEcts(1.5), '1,5');
      expect(formatEcts(7.25), '7,25');
      expect(formatEcts(5.0), '5');
    });

    test('parse comma and dot, in quarter steps', () {
      expect(parseLectureEcts('1,5'), 1.5);
      expect(parseLectureEcts(' 2.25 '), 2.25);
      expect(parseLectureEcts('6'), 6);
      for (final bad in ['', 'abc', '0', '31', '1,3', '-2']) {
        expect(() => parseLectureEcts(bad), throwsFormatException,
            reason: bad);
      }
    });

    test('a half ECTS survives JSON, a whole one stays a whole number', () {
      final half = Lecture.fromJson(_lecture('Ethik', 1.5).toJson());
      expect(half.ects, 1.5);
      final whole = _lecture('Mathe', 5).toJson();
      expect(whole['ects'], 5);
      expect(whole['ects'], isA<int>());
    });

    test('totals and the weighted average add halves up', () {
      final sem = Semester(id: 's1', number: 1, season: 'winter', lectures: [
        _lecture('A', 1.5, grade: 1.0),
        _lecture('B', 4.5, grade: 3.0),
        _lecture('C', 2),
      ]);
      expect(sem.totalEcts, 8);
      expect(sem.passedEcts, 6);
      // (1.5 * 1.0 + 4.5 * 3.0) / 6
      expect(sem.averageGrade(weightedByEcts: true), 2.5);
      final plan = StudyPlan(semesters: [sem], targetEcts: 10);
      expect(plan.targetDelta, -2);
      expect(targetDeltaLabel(-1.5), 'noch 1,5 ECTS offen');
    });
  });

  group('GradeScale', () {
    test('Germany takes only its steps', () {
      const de = GradeScale.germany;
      expect(de.parse('2,3'), 2.3);
      expect(de.parse('2.0'), 2.0);
      expect(de.parse('2'), 2.0);
      expect(() => de.parse('2,1'), throwsFormatException);
      expect(() => de.parse('5'), throwsFormatException);
      expect(de.format(2), '2,0');
    });

    test('Austria takes whole grades only', () {
      const at = GradeScale.austria;
      expect(at.parse('2'), 2);
      expect(at.format(2), '2');
      expect(() => at.parse('2,3'), throwsFormatException);
      expect(at.steps, [1, 2, 3, 4]);
    });

    test('free takes tenths from 1,0 to 5,0', () {
      const free = GradeScale.free;
      expect(free.parse('2,1'), 2.1);
      expect(() => free.parse('2,15'), throwsFormatException);
      expect(() => free.parse('0,9'), throwsFormatException);
    });

    test('unknown ids fall back to Germany', () {
      expect(GradeScale.fromId('at'), GradeScale.austria);
      expect(GradeScale.fromId(null), GradeScale.germany);
      expect(GradeScale.fromId('xx'), GradeScale.germany);
    });

    test('averages always get one decimal', () {
      expect(formatAverageGrade(2), '2,0');
      expect(formatAverageGrade(2.25), '2,3');
    });
  });

  group('Plan settings', () {
    test('grade scale and start year survive JSON', () {
      final plan = StudyPlan(gradeScale: GradeScale.austria, startYear: 2025);
      final back = StudyPlan.fromJson(plan.toJson());
      expect(back.gradeScale, GradeScale.austria);
      expect(back.startYear, 2025);
      // Older plans have neither.
      final old = StudyPlan.fromJson({'planName': 'Alt'});
      expect(old.gradeScale, GradeScale.germany);
      expect(old.startYear, isNull);
      expect(StudyPlan.fromJson({'startYear': 1800}).startYear, isNull);
    });

    test('semester terms count from the start', () {
      final winter = StudyPlan(startSeason: 'winter', startYear: 2025);
      expect(winter.termLabel(1, 'winter'), 'WS 2025/26');
      expect(winter.termLabel(2, 'summer'), 'SS 2026');
      expect(winter.termLabel(3, 'winter'), 'WS 2026/27');
      final summer = StudyPlan(startSeason: 'summer', startYear: 2099);
      expect(summer.termLabel(1, 'summer'), 'SS 2099');
      expect(summer.termLabel(2, 'winter'), 'WS 2099/00');
      expect(StudyPlan().termLabel(1, 'winter'), 'WS');
    });

    test('start year input', () {
      expect(StudyPlan.parseStartYear(''), isNull);
      expect(StudyPlan.parseStartYear('2025'), 2025);
      expect(() => StudyPlan.parseStartYear('25'), throwsFormatException);
    });
  });
}
