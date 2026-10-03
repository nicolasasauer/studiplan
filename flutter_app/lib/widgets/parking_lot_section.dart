import 'package:flutter/material.dart';
import '../models/lecture.dart';
import '../models/semester.dart';
import '../providers/study_plan_provider.dart';
import 'add_lecture_dialog.dart';
import 'lecture_card.dart';
import 'lecture_drag.dart';
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
    return LectureDropZone(
      id: LectureDragController.parkingLot,
      collapsed: _collapsed,
      onExpand: () => setState(() => _collapsed = false),
      margin: const EdgeInsets.only(bottom: 8),
      builder: (context, highlight) => Card(
      margin: EdgeInsets.zero,
      child: Column(children: [
        InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
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
              // Title and drop hint give way on a phone, so the row fits
              // even while a lecture is dragged over it.
              Expanded(
                // Title and count both give way, so the row never overflows.
                child: Row(children: [
                  Flexible(
                    flex: 3,
                    child: Text('Parkplatz',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text('${widget.lectures.length} VL',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                              color: context.cs.onSurfaceVariant, fontSize: 12)),
                    ),
                  ),
                ]),
              ),
              if (highlight != null) ...[
                Flexible(child: DropHint(highlight)),
                const SizedBox(width: 8),
              ],
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
      ),
    );
  }
}
