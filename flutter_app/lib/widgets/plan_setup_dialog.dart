import 'package:flutter/material.dart';

class PlanSetupDialog extends StatefulWidget {
  final String initialName;
  final int initialSemesters;
  final String initialSeason;
  final Future<void> Function(String name, int semesters, String season)
      onSave;

  const PlanSetupDialog({
    super.key,
    required this.initialName,
    required this.initialSemesters,
    required this.initialSeason,
    required this.onSave,
  });

  @override
  State<PlanSetupDialog> createState() => _PlanSetupDialogState();
}

class _PlanSetupDialogState extends State<PlanSetupDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late int _semesters;
  late String _season;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _semesters = widget.initialSemesters;
    _season = widget.initialSeason;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        _nameCtrl.text.trim().isEmpty
            ? 'Mein Studienplan'
            : _nameCtrl.text.trim(),
        _semesters,
        _season,
      );
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Plan einrichten',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                  'Lege Planname und Regelstudienzeit fest.',
                  style:
                      TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Planname',
                    hintText: 'z.B. Informatik B.Sc.'),
                maxLength: 80,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Regelstudienzeit (Semester)',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      Row(children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: _semesters > 1
                              ? () => setState(() => _semesters--)
                              : null,
                        ),
                        Text('$_semesters',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: _semesters < 20
                              ? () => setState(() => _semesters++)
                              : null,
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Startsemester',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _season,
                        dropdownColor: const Color(0xFF334155),
                        decoration: const InputDecoration(isDense: true),
                        items: const [
                          DropdownMenuItem(
                              value: 'winter',
                              child: Text('Wintersemester')),
                          DropdownMenuItem(
                              value: 'summer',
                              child: Text('Sommersemester')),
                        ],
                        onChanged: (v) =>
                            setState(() => _season = v ?? _season),
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: _saving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _save,
                        child: const Text('Plan starten'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
