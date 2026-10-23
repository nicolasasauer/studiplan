import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/grade_scale.dart';
import '../models/study_plan.dart';
import '../services/theme_service.dart';
import 'target_ects_field.dart';

/// What the settings dialog saves, in one go.
typedef PlanSettings = ({
  bool weightAverageGradeByEcts,
  int? targetEcts,
  GradeScale gradeScale,
  int? startYear,
});

class PlanSettingsDialog extends StatefulWidget {
  final bool initialWeightAverageGradeByEcts;
  final int? initialTargetEcts;
  final GradeScale initialGradeScale;
  final int? initialStartYear;

  /// The plan's first semester, for the start year's label ("WS"/"SS").
  final String startSeason;
  final Future<void> Function(PlanSettings settings) onSave;

  const PlanSettingsDialog({
    super.key,
    required this.initialWeightAverageGradeByEcts,
    this.initialTargetEcts,
    this.initialGradeScale = GradeScale.fallback,
    this.initialStartYear,
    this.startSeason = 'winter',
    required this.onSave,
  });

  @override
  State<PlanSettingsDialog> createState() => _PlanSettingsDialogState();
}

class _PlanSettingsDialogState extends State<PlanSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late bool _weightAverageGradeByEcts;
  late final TextEditingController _targetCtrl;
  late final TextEditingController _startYearCtrl;
  late GradeScale _gradeScale;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _weightAverageGradeByEcts = widget.initialWeightAverageGradeByEcts;
    _targetCtrl =
        TextEditingController(text: widget.initialTargetEcts?.toString() ?? '');
    _startYearCtrl =
        TextEditingController(text: widget.initialStartYear?.toString() ?? '');
    _gradeScale = widget.initialGradeScale;
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    _startYearCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave((
        weightAverageGradeByEcts: _weightAverageGradeByEcts,
        targetEcts: StudyPlan.parseTargetEcts(_targetCtrl.text),
        gradeScale: _gradeScale,
        startYear: StudyPlan.parseStartYear(_startYearCtrl.text),
      ));
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final theme = context.watch<ThemeService>();
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Einstellungen',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                'Darstellung',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Gilt nur auf diesem Gerät und sofort.',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, constraints) {
                // On a phone three segments with icon and check mark do not fit, and
                // the labels would break mid-word.
                final narrow = constraints.maxWidth < 360;
                ButtonSegment<ThemeMode> segment(
                        ThemeMode mode, IconData icon, String label) =>
                    ButtonSegment(
                      value: mode,
                      icon: narrow ? null : Icon(icon),
                      label: Text(label, maxLines: 1, softWrap: false),
                    );
                return SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    key: const ValueKey('theme-mode'),
                    showSelectedIcon: !narrow,
                    segments: [
                      segment(
                          ThemeMode.system, Icons.brightness_auto_rounded, 'System'),
                      segment(ThemeMode.light, Icons.light_mode_rounded, 'Hell'),
                      segment(ThemeMode.dark, Icons.dark_mode_rounded, 'Dunkel'),
                    ],
                    selected: {theme.mode},
                    onSelectionChanged: (selection) =>
                        context.read<ThemeService>().setMode(selection.first),
                  ),
                );
              }),
              const SizedBox(height: 24),
              const Text(
                'Plan',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TargetEctsField(
                controller: _targetCtrl,
                enabled: !_saving,
                onSubmitted: _save,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('start-year'),
                controller: _startYearCtrl,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Studienbeginn (optional)',
                  hintText: 'z. B. 2025',
                  prefixText:
                      widget.startSeason == 'winter' ? 'WS ' : 'SS ',
                  helperText: 'Damit tragen die Semester ihr Jahr, und Focus '
                      'Flow erkennt das aktuelle.',
                  helperMaxLines: 2,
                ),
                validator: (text) {
                  try {
                    StudyPlan.parseStartYear(text ?? '');
                    return null;
                  } on FormatException catch (e) {
                    return e.message;
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<GradeScale>(
                key: const Key('grade-scale'),
                initialValue: _gradeScale,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Notensystem',
                  helperText: _gradeScale.summary,
                ),
                items: [
                  for (final scale in GradeScale.values)
                    DropdownMenuItem(value: scale, child: Text(scale.label)),
                ],
                onChanged: _saving
                    ? null
                    : (scale) {
                        if (scale != null) setState(() => _gradeScale = scale);
                      },
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _weightAverageGradeByEcts,
                title: const Text('Durchschnittsnote nach ECTS gewichten'),
                subtitle: Text(
                  'Größere Module beeinflussen die Gesamt- und Semesternote stärker.',
                  style: TextStyle(color: muted),
                ),
                onChanged: _saving
                    ? null
                    : (value) {
                        setState(() => _weightAverageGradeByEcts = value);
                      },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: _saving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _save,
                        child: const Text('Speichern'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
