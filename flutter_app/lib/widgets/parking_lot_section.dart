import 'package:flutter/material.dart';
import '../models/lecture.dart';
import '../models/semester.dart';
import '../providers/study_plan_provider.dart';
import 'add_lecture_dialog.dart';
import 'lecture_card.dart';
import '../theme/app_theme.dart';

class ParkingLotSection extends StatefulWidget {
  final List<Lecture> lectures;
  final List<Semester> semesters;
  final StudyPlanProvider provider;

  const ParkingLotSection({
    super.key,
    required this.lectures,
    required this.semesters,
    required this.provider,
  });

  @override
  State<ParkingLotSection> createState() => _ParkingLotSectionState();
}

class _ParkingLotSectionState extends State<ParkingLotSection> {
  bool _collapsed = true;

  void _addLecture(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AddLectureDialog(
        semesters: widget.semesters,
        onSave: (l, semId) => widget.provider.addLecture(l, semId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
              Icon(Icons.local_parking,
                  color: context.tone(Colors.orange), size: 18),
              const SizedBox(width: 6),
              const Text('Parkplatz',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(width: 6),
              Text('${widget.lectures.length} VL',
                  style: TextStyle(
                      color: context.cs.onSurfaceVariant, fontSize: 12)),
              const Spacer(),
              if (widget.lectures.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.tone(Colors.orange).withAlpha(40),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${widget.lectures.fold(0, (s, l) => s + l.ects)} ECTS',
                    style: TextStyle(
                        fontSize: 10, color: context.tone(Colors.orange)),
                  ),
                ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.add,
                    color: context.cs.onSurfaceVariant, size: 18),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Zum Parkplatz hinzufügen',
                onPressed: () => _addLecture(context),
              ),
            ]),
          ),
        ),
        if (!_collapsed && widget.lectures.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Column(
              children: widget.lectures
                  .map((l) => LectureCard(
                      lecture: l, allSemesters: widget.semesters))
                  .toList(),
            ),
          ),
        if (!_collapsed && widget.lectures.isEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text('Keine Veranstaltungen im Parkplatz.',
                style:
                    TextStyle(color: context.cs.outline, fontSize: 12)),
          ),
      ]),
    );
  }
}
