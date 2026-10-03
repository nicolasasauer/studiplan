import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/study_plan.dart';
import '../providers/study_plan_provider.dart';
import '../models/lecture.dart';
import '../widgets/add_lecture_dialog.dart';
import '../widgets/lecture_drag.dart';
import '../widgets/parking_lot_section.dart';
import '../widgets/plan_setup_dialog.dart';
import '../widgets/plan_settings_dialog.dart';
import '../widgets/plan_transfer.dart';
import '../widgets/semester_section.dart';
import '../widgets/share_local_plan_dialog.dart';
import '../theme/app_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _nameCtrl = TextEditingController();
  bool _editingName = false;
  bool _bannerDismissed = false;
  bool _setupDialogScheduled = false;
  bool _setupDialogOpen = false;

  final _listScroll = ScrollController();
  final _listViewport = GlobalKey();
  late final LectureDragController _drag =
      LectureDragController(onDrop: _onLectureDrop)
        ..attachList(_listScroll, _listViewport);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _drag.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  Lecture? _lectureById(StudyPlanProvider p, String id) {
    for (final sem in p.plan.semesters) {
      for (final l in sem.lectures) {
        if (l.id == id) return l;
      }
    }
    for (final l in p.plan.parkingLot) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// A lecture was dragged onto [target]: move it and offer to undo.
  Future<void> _onLectureDrop(
      LectureDragData data, DropTargetId target) async {
    final p = context.read<StudyPlanProvider>();
    final from = p.locateLecture(data.lectureId);
    final lecture = _lectureById(p, data.lectureId);
    if (from == null || lecture == null) return; // Gone meanwhile (sync).

    final to = target == LectureDragController.parkingLot ? null : target;
    if (!await p.moveLecture(data.lectureId, to)) return;
    if (!mounted) return;

    final where = to == null
        ? 'Parkplatz'
        : '${p.plan.semesters.firstWhere((s) => s.id == to).number}. Semester';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${lecture.name} → $where'),
        // Long enough to reach "Rückgängig" after noticing a wrong drop.
        duration: const Duration(seconds: 8),
        // With an action the bar would otherwise stay until dismissed.
        persist: false,
        action: SnackBarAction(
          label: 'Rückgängig',
          onPressed: () async {
            final back = await p.moveLecture(data.lectureId, from.semesterId,
                index: from.index);
            // Its old semester was deleted in the meantime: the parking lot
            // is where that semester's lectures went, too.
            if (!back &&
                from.semesterId != null &&
                p.plan.semesters.every((s) => s.id != from.semesterId)) {
              await p.moveLecture(data.lectureId, null);
            }
          },
        ),
      ));
  }

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  void _toast(String text, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  Future<void> _export(StudyPlanProvider p) async {
    // Desktop (Linux) has no share menu for files.
    final action = await showExportOptions(context, canShare: !_isDesktop);
    if (action == null) return;
    try {
      final json = p.exportJson();
      switch (action) {
        case ExportAction.copyText:
          await Clipboard.setData(ClipboardData(text: json));
          _toast('Plan als Text in die Zwischenablage kopiert');
        case ExportAction.saveFile:
          // Writes the file itself (on Android via the system's file
          // dialog); returns null when cancelled.
          final saved = await FilePicker.saveFile(
            dialogTitle: 'Plan exportieren',
            fileName: 'studi_plan_export.json',
            bytes: utf8.encode(json),
            mimeType: 'application/json',
            type: FileType.custom,
            allowedExtensions: ['json'],
          );
          if (saved == null) return;
          // Android hands back a content:// URI, which means nothing to
          // the user, so only desktop paths are shown.
          _toast(saved.scheme == 'file'
              ? 'Plan gespeichert: ${saved.toFilePath()}'
              : 'Plan gespeichert');
        case ExportAction.share:
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/studi_plan_export.json');
          await file.writeAsString(json);
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(file.path, mimeType: 'application/json')],
              subject: 'StudiPlan Export',
            ),
          );
      }
    } catch (e) {
      _toast('Export fehlgeschlagen: $e');
    }
  }

  Future<void> _shareLocalPlan() async {
    final shared = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ShareLocalPlanDialog(),
    );
    if (shared == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Plan wird jetzt mit dem Server synchronisiert. '
            'Die lokale Kopie liegt im Archiv.'),
        backgroundColor: context.tone(Colors.green),
      ));
    }
  }

  Future<void> _import(StudyPlanProvider p) async {
    final action = await showImportOptions(context);
    if (action == null || !mounted) return;
    final String? content;
    if (action == ImportAction.pasteText) {
      content = await showDialog<String>(
        context: context,
        builder: (_) => const PasteImportDialog(),
      );
    } else {
      content = await _readImportFile();
    }
    if (content == null) return;
    final err = await p.importJson(content);
    if (!mounted) return;
    _toast(err ?? 'Plan erfolgreich importiert',
        color: err == null ? context.tone(Colors.green) : context.cs.error);
  }

  Future<String?> _readImportFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (files.isEmpty) return null;
    try {
      return utf8.decode(await files.first.readAsBytes());
    } catch (e) {
      if (mounted) {
        _toast('Datei konnte nicht gelesen werden: $e',
            color: context.cs.error);
      }
      return null;
    }
  }

  void _deleteAccount(StudyPlanProvider p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Konto löschen?'),
        content: Text(
          'Soll das Konto "${p.currentUser}" unwiderruflich gelöscht werden? '
          'Alle Daten gehen dabei verloren.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: context.cs.error,
                foregroundColor: context.cs.onError),
            onPressed: () async {
              Navigator.pop(context);
              final err = await p.deleteAccount();
              if (err != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Fehler: $err'),
                  backgroundColor: context.cs.error,
                ));
              }
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  void _addLecture(StudyPlanProvider p) {
    showDialog(
      context: context,
      builder: (_) => AddLectureDialog(
        semesters: p.plan.semesters,
        onSave: (l, semId) => p.addLecture(l, semId),
      ),
    );
  }

  Future<void> _openSetup(StudyPlanProvider p,
      {bool barrierDismissible = true}) async {
    if (_setupDialogOpen) return;

    _setupDialogOpen = true;
    try {
      await showDialog(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (_) => PlanSetupDialog(
          initialName: p.plan.planName,
          initialSemesters: p.plan.regularSemesters,
          initialSeason: p.plan.startSeason,
          onSave: (name, n, season, targetEcts) async {
            try {
              await p.initializePlan(name, n, season, targetEcts: targetEcts);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Fehler beim Erstellen des Plans: $e'),
                    backgroundColor: context.cs.error,
                  ),
                );
              }
            }
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dialog-Fehler: $e'),
            backgroundColor: context.cs.error,
          ),
        );
      }
    } finally {
      _setupDialogOpen = false;
    }
  }

  Future<void> _openSettings(StudyPlanProvider p) async {
    await showDialog(
      context: context,
      builder: (_) => PlanSettingsDialog(
        initialWeightAverageGradeByEcts: p.plan.weightAverageGradeByEcts,
        initialTargetEcts: p.plan.targetEcts,
        onSave: (weighted, targetEcts) => p.updatePlanSettings(
            weightAverageGradeByEcts: weighted, targetEcts: targetEcts),
      ),
    );
  }

  void _closeSetupIfNoLongerNeeded(StudyPlanProvider p) {
    if (!_setupDialogOpen || !p.plan.isEffectivelyConfigured) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_setupDialogOpen) return;
      Navigator.of(context, rootNavigator: true).maybePop();
    });
  }

  void _scheduleInitialSetupIfNeeded(StudyPlanProvider p) {
    if (_setupDialogScheduled ||
        _setupDialogOpen ||
        !p.isLoggedIn ||
        p.plan.isEffectivelyConfigured) {
      return;
    }

    _setupDialogScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _setupDialogScheduled = false;
        return;
      }

      final provider = context.read<StudyPlanProvider>();
      if (!provider.isLoggedIn || provider.plan.isEffectivelyConfigured) {
        _setupDialogScheduled = false;
        return;
      }

      await _openSetup(provider, barrierDismissible: false);
      if (mounted) {
        _setupDialogScheduled = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<StudyPlanProvider>();
    final plan = p.plan;

    _closeSetupIfNoLongerNeeded(p);
    _scheduleInitialSetupIfNeeded(p);

    return LectureDragScope(
      controller: _drag,
      child: LectureDragListener(
      controller: _drag,
      child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(p),
            if (!_bannerDismissed) _buildBanner(),
            Expanded(
              child: KeyedSubtree(
                key: _listViewport,
                child: RefreshIndicator(
                onRefresh: p.refreshPlanFromServer,
                child: ListView(
                  controller: _listScroll,
                  padding: const EdgeInsets.all(12),
                  children: [
                    _buildStats(plan),
                    const SizedBox(height: 12),
                    ParkingLotSection(
                        lectures: plan.parkingLot,
                        semesters: plan.semesters,
                        provider: p),
                    const SizedBox(height: 8),
                    ...plan.semesters.map(
                        (sem) => SemesterSection(semester: sem, provider: p)),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Veranstaltung'),
        onPressed: () => _addLecture(p),
      ),
    ),
      ),
    );
  }

  Widget _buildHeader(StudyPlanProvider p) => Container(
        color: context.cs.surface,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: LayoutBuilder(builder: (context, constraints) {
        // On a phone the row of icons would leave no room for the plan name,
        // so the less frequent actions move into a menu.
        final narrow = constraints.maxWidth < _narrowWidth;
        return Row(
          children: [
            Icon(Icons.school, color: context.tone(Colors.blue), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: _editingName
                  ? TextField(
                      controller: _nameCtrl,
                      autofocus: true,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: context.cs.onSurface),
                      decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4)),
                      onSubmitted: (v) {
                        if (v.trim().isNotEmpty) p.updatePlanName(v.trim());
                        setState(() => _editingName = false);
                      },
                    )
                  : GestureDetector(
                      onTap: () {
                        _nameCtrl.text = p.plan.planName;
                        setState(() => _editingName = true);
                      },
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              p.plan.planName,
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: context.cs.onSurface),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.edit,
                              size: 14, color: context.cs.onSurfaceVariant),
                        ],
                      ),
                    ),
            ),
            ..._headerActions(p, narrow),
          ],
        );
        }),
      );

  /// Below this width the header and the stat cards use their compact form.
  static const _narrowWidth = 600.0;

  List<Widget> _headerActions(StudyPlanProvider p, bool narrow) {
    final muted = context.cs.onSurfaceVariant;
    Widget action(IconData icon, String tooltip, VoidCallback onPressed,
            {Color? color}) =>
        IconButton(
            icon: Icon(icon, color: color ?? muted, size: 20),
            tooltip: tooltip,
            onPressed: onPressed);

    final unsynced = p.hasUnsyncedChanges
        ? action(
            Icons.cloud_off,
            'Änderungen noch nicht auf dem Server. Tippen zum erneuten Senden.',
            p.refreshPlanFromServer,
            color: context.tone(Colors.amber))
        : null;
    final settingsTooltip = p.plan.isEffectivelyConfigured
        ? 'Planeinstellungen'
        : 'Plan einrichten';
    void openSettings() => p.plan.isEffectivelyConfigured
        ? _openSettings(p)
        : _openSetup(p);
    final localBadge = p.localMode
        ? Tooltip(
            message: 'Lokaler Modus – keine Serververbindung',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.phone_android,
                  color: context.tone(Colors.amber), size: 18),
            ),
          )
        : null;

    if (!narrow) {
      return [
        if (p.localMode)
          action(Icons.cloud_upload, 'Mit Server synchronisieren',
              _shareLocalPlan),
        ?unsynced,
        action(Icons.download, 'Importieren', () => _import(p)),
        action(Icons.upload, 'Exportieren', () => _export(p)),
        action(Icons.add_circle_outline, 'Semester hinzufügen',
            () => p.addSemester()),
        action(Icons.settings, settingsTooltip, openSettings),
        ?localBadge,
        if (!p.localMode)
          action(Icons.person_remove, 'Konto löschen', () => _deleteAccount(p),
              color: context.tone(Colors.red)),
        action(Icons.logout, 'Abmelden', () => p.logout()),
      ];
    }

    PopupMenuItem<VoidCallback> item(
            IconData icon, String label, VoidCallback onTap,
            {Color? color}) =>
        PopupMenuItem(
          value: onTap,
          child: Row(children: [
            Icon(icon, size: 20, color: color ?? muted),
            const SizedBox(width: 12),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: color == null ? null : TextStyle(color: color)),
            ),
          ]),
        );
    return [
      ?unsynced,
      ?localBadge,
      action(Icons.settings, settingsTooltip, openSettings),
      PopupMenuButton<VoidCallback>(
        key: const Key('header-menu'),
        icon: Icon(Icons.more_vert, color: muted, size: 20),
        tooltip: 'Weitere Aktionen',
        onSelected: (run) => run(),
        itemBuilder: (_) => [
          item(Icons.add_circle_outline, 'Semester hinzufügen',
              () => p.addSemester()),
          item(Icons.download, 'Importieren', () => _import(p)),
          item(Icons.upload, 'Exportieren', () => _export(p)),
          if (p.localMode)
            item(Icons.cloud_upload, 'Mit Server synchronisieren',
                _shareLocalPlan),
          const PopupMenuDivider(),
          if (!p.localMode)
            item(Icons.person_remove, 'Konto löschen', () => _deleteAccount(p),
                color: context.tone(Colors.red)),
          item(Icons.logout, 'Abmelden', () => p.logout()),
        ],
      ),
    ];
  }

  Widget _buildBanner() => Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.tone(Colors.blue).withAlpha(30),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.tone(Colors.blue).withAlpha(120)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: context.tone(Colors.blue), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'WS/SS bei Veranstaltungen ist ein Hinweis zum Turnus. '
                'Klausuren können weiterhin in jedem Semester geplant werden.',
                style: TextStyle(color: context.tone(Colors.blue), fontSize: 12),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 14, color: context.tone(Colors.blue)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () =>
                  setState(() => _bannerDismissed = true),
            ),
          ],
        ),
      );

  Widget _buildStats(StudyPlan plan) {
    final total = plan.totalEcts;
    final passed = plan.passedEcts;
    final avg = plan.averageGrade;
    final target = plan.targetEcts;
    final delta = plan.targetDelta;
    if (total == 0) return const SizedBox.shrink();
    // Same height for all cards, even when one has a progress bar.
    return LayoutBuilder(builder: (context, constraints) {
    // Three cards side by side on a phone leave no room for the icon, and
    // captions need a second line.
    final compact = constraints.maxWidth < _narrowWidth;
    return IntrinsicHeight(
        child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _statCard(
          compact: compact,
          key: const Key('stat-planned'),
          // On a phone the unit would shrink the numbers; the caption
          // below says ECTS anyway.
          value: target == null
              ? '$total ECTS'
              : compact
                  ? '$total / $target'
                  : '$total / $target ECTS',
          label: 'Geplant',
          icon: Icons.event_note_rounded,
          color: Colors.blue,
          caption: delta == null
              ? '${plan.semesters.length} Semester'
              : targetDeltaLabel(delta),
          // More planned than the degree needs: worth a second look.
          captionColor: delta != null && delta > 0
              ? context.tone(Colors.orange)
              : null,
          progress: target == null ? null : (total / target).clamp(0.0, 1.0),
        ),
        const SizedBox(width: 12),
        _statCard(
          compact: compact,
          key: const Key('stat-passed'),
          value: '$passed ECTS',
          label: 'Bestanden',
          icon: Icons.verified_rounded,
          color: Colors.green,
          caption: target == null
              ? '${(passed * 100 / total).round()} % geschafft'
              : '${(passed * 100 / target).round()} % vom Studium',
        ),
        if (avg != null) ...[
          const SizedBox(width: 12),
          _statCard(
            compact: compact,
            value: 'Ø ${avg.toStringAsFixed(1)}',
            label: 'Notenschnitt',
            icon: Icons.grade_rounded,
            color: Colors.purple,
            caption: plan.weightAverageGradeByEcts ? 'nach ECTS gewichtet' : null,
          ),
        ],
      ],
    ));
    });
  }

  /// A stat card like Focus Flow's: tinted icon, label, big value, caption.
  Widget _statCard({
    Key? key,
    required String value,
    required String label,
    required IconData icon,
    required MaterialColor color,
    String? caption,
    Color? captionColor,
    double? progress,
    bool compact = false,
  }) {
    final theme = Theme.of(context);
    final accent = context.tone(color);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Expanded(
      key: key,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (!compact) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: accent),
                ),
                const SizedBox(width: 8),
                ],
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(label,
                        maxLines: 1,
                        softWrap: false,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: muted)),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                // One line: FittedBox shrinks it instead of letting it wrap,
                // which would also blow up the intrinsic height of the row.
                child: Text(value,
                    maxLines: 1,
                    softWrap: false,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              if (caption != null)
                Text(caption,
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: captionColor ?? muted)),
              if (progress != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    color: accent,
                    backgroundColor: accent.withValues(alpha: 0.15),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
