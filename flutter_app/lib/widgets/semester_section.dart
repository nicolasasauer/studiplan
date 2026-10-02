import 'package:flutter/material.dart';
import '../models/semester.dart';
import '../providers/study_plan_provider.dart';
import 'add_lecture_dialog.dart';
import 'lecture_card.dart';
import '../theme/app_theme.dart';

class SemesterSection extends StatefulWidget {
  final Semester semester;
  final StudyPlanProvider provider;

  const SemesterSection(
      {super.key, required this.semester, required this.provider});

  @override
  State<SemesterSection> createState() => _SemesterSectionState();
}

class _SemesterSectionState extends State<SemesterSection> {
  bool _collapsed = true;

  Semester get sem => widget.semester;
  StudyPlanProvider get p => widget.provider;

  Color get _seasonColor =>
      sem.season == 'winter' ? context.tone(Colors.blue) : context.tone(Colors.orange);
  String get _seasonLabel => sem.season == 'winter' ? 'WS' : 'SS';

  void _delete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Semester löschen?'),
        content: Text(
          'Soll das ${sem.number}. Semester gelöscht werden? '
          'Alle Veranstaltungen kommen in den Parkplatz.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: context.cs.error,
                foregroundColor: context.cs.onError),
            onPressed: () {
              Navigator.pop(context);
              p.removeSemester(sem.id);
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  void _addLecture(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AddLectureDialog(
        initialSemesterId: sem.id,
        semesters: p.plan.semesters,
        onSave: (l, semId) => p.addLecture(l, semId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avg =
        sem.averageGrade(weightedByEcts: p.plan.weightAverageGradeByEcts);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(children: [
        InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          onTap: () => setState(() => _collapsed = !_collapsed),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(_collapsed ? Icons.expand_more : Icons.expand_less,
                  color: context.cs.onSurfaceVariant, size: 20),
              const SizedBox(width: 6),
              _seasonBadge(),
              const SizedBox(width: 8),
              Text('${sem.number}. Semester',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(width: 6),
              Text('${sem.lectures.length} VL',
                  style: TextStyle(
                      color: context.cs.onSurfaceVariant, fontSize: 12)),
              const Spacer(),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _miniChip('${sem.totalEcts} ECTS', context.tone(Colors.blue)),
                  if (sem.passedEcts > 0) ...[
                    const SizedBox(width: 6),
                    _miniChip('✓ ${sem.passedEcts}', context.tone(Colors.green)),
                  ],
                  if (avg != null) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: p.plan.weightAverageGradeByEcts
                          ? 'ECTS-gewichtete Durchschnittsnote'
                          : 'Ungewichtete Durchschnittsnote',
                      child:
                          _miniChip('Ø ${avg.toStringAsFixed(1)}', context.tone(Colors.purple)),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.add_circle_outline,
                        color: context.cs.onSurfaceVariant, size: 20),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Veranstaltung hinzufügen',
                    onPressed: () => _addLecture(context),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        color: context.cs.onSurfaceVariant, size: 20),
                    tooltip: 'Weitere Optionen',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    onSelected: (v) {
                      if (v == 'delete') {
                        _delete(context);
                      } else {
                        p.sortSemesterLectures(sem.id, v);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'date', child: Text('Sortieren: Prüfungsdatum')),
                      const PopupMenuItem(
                          value: 'ects', child: Text('Sortieren: ECTS')),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Semester löschen',
                            style: TextStyle(color: context.cs.error)),
                      ),
                    ],
                  ),
                ],
              ),
            ]),
          ),
        ),
        if (!_collapsed && sem.lectures.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Column(
              children: sem.lectures
                  .map((l) => LectureCard(
                        lecture: l,
                        allSemesters: p.plan.semesters,
                      ))
                  .toList(),
            ),
          ),
        if (!_collapsed && sem.lectures.isEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text('Keine Veranstaltungen in diesem Semester.',
                style:
                    TextStyle(color: context.cs.outline, fontSize: 12)),
          ),
      ]),
    );
  }

  Widget _seasonBadge() => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _seasonColor.withAlpha(50),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _seasonColor.withAlpha(128)),
        ),
        child: Text(_seasonLabel,
            style: TextStyle(
                color: _seasonColor,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      );

  Widget _miniChip(String text, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600)),
      );
}
