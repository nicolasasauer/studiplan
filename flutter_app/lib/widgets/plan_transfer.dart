import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Ways to get the plan out of the app.
enum ExportAction { saveFile, share, copyText }

/// Ways to get a plan into the app.
enum ImportAction { pickFile, pasteText }

/// Bottom sheet listing the export options. [canShare] is false where the
/// platform has no share menu for files (desktop).
Future<ExportAction?> showExportOptions(
  BuildContext context, {
  required bool canShare,
}) {
  return showModalBottomSheet<ExportAction>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetTitle('Plan exportieren'),
          ListTile(
            key: const Key('export-save'),
            leading: const Icon(Icons.save_alt),
            title: const Text('Als Datei speichern'),
            subtitle: const Text('JSON-Datei in einem Ordner ablegen'),
            onTap: () => Navigator.pop(context, ExportAction.saveFile),
          ),
          if (canShare)
            ListTile(
              key: const Key('export-share'),
              leading: const Icon(Icons.share),
              title: const Text('Teilen …'),
              subtitle: const Text('Per Messenger, Mail oder Cloud senden'),
              onTap: () => Navigator.pop(context, ExportAction.share),
            ),
          ListTile(
            key: const Key('export-copy'),
            leading: const Icon(Icons.copy),
            title: const Text('Als Text kopieren'),
            subtitle: const Text('JSON in die Zwischenablage'),
            onTap: () => Navigator.pop(context, ExportAction.copyText),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Bottom sheet listing the import options.
Future<ImportAction?> showImportOptions(BuildContext context) {
  return showModalBottomSheet<ImportAction>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetTitle('Plan importieren'),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Der importierte Plan ersetzt den aktuellen.'),
            ),
          ),
          ListTile(
            key: const Key('import-file'),
            leading: const Icon(Icons.folder_open),
            title: const Text('Aus Datei'),
            onTap: () => Navigator.pop(context, ImportAction.pickFile),
          ),
          ListTile(
            key: const Key('import-paste'),
            leading: const Icon(Icons.content_paste),
            title: const Text('Text einfügen'),
            subtitle: const Text('Kopiertes JSON übernehmen'),
            onTap: () => Navigator.pop(context, ImportAction.pasteText),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

/// Dialog with a text field for pasted plan JSON. Starts with whatever is on
/// the clipboard; returns the text to import, or null when cancelled.
class PasteImportDialog extends StatefulWidget {
  const PasteImportDialog({super.key});

  @override
  State<PasteImportDialog> createState() => _PasteImportDialogState();
}

class _PasteImportDialogState extends State<PasteImportDialog> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
    _pasteFromClipboard();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    // Only take clipboard text that looks like a plan, so a stray link or
    // word does not end up in the field.
    if (!mounted || _ctrl.text.isNotEmpty || !text.startsWith('{')) return;
    _ctrl.text = text;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _ctrl.text.trim();
    return AlertDialog(
      title: const Text('Plan aus Text importieren'),
      content: TextField(
        key: const Key('paste-field'),
        controller: _ctrl,
        minLines: 6,
        maxLines: 12,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        decoration: const InputDecoration(
          hintText: '{ "planName": … }',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const Key('paste-import'),
          onPressed: text.isEmpty ? null : () => Navigator.pop(context, text),
          child: const Text('Importieren'),
        ),
      ],
    );
  }
}
