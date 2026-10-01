import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/study_plan_provider.dart';

/// Gibt den lokalen Plan zur Synchronisierung frei: Anmeldung an einem
/// Server (oder neues Konto), danach Upload und Wechsel in den Servermodus.
///
/// Gibt `true` zurück, wenn die App jetzt mit dem Server synchronisiert.
class ShareLocalPlanDialog extends StatefulWidget {
  const ShareLocalPlanDialog({super.key});

  @override
  State<ShareLocalPlanDialog> createState() => _ShareLocalPlanDialogState();
}

class _ShareLocalPlanDialogState extends State<ShareLocalPlanDialog> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _userCtrl;
  final _pwCtrl = TextEditingController();
  bool _createAccount = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final provider = context.read<StudyPlanProvider>();
    _urlCtrl = TextEditingController(text: provider.baseUrl);
    _userCtrl = TextEditingController(text: provider.currentUser ?? '');
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _share([
    ServerPlanResolution resolution = ServerPlanResolution.ask,
  ]) async {
    if (_urlCtrl.text.trim().isEmpty || _userCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Bitte Server-URL und Benutzername angeben.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await context.read<StudyPlanProvider>().shareLocalPlan(
          serverUrl: _urlCtrl.text,
          username: _userCtrl.text,
          password: _pwCtrl.text.isEmpty ? null : _pwCtrl.text,
          createAccount: _createAccount,
          resolution: resolution,
        );
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result.status) {
      case ShareLocalPlanStatus.shared:
        Navigator.pop(context, true);
      case ShareLocalPlanStatus.serverHasPlan:
        final choice = await _askConflict();
        if (choice != null && mounted) await _share(choice);
      case ShareLocalPlanStatus.requiresPassword:
        setState(() => _error = 'Dieses Konto hat ein Passwort.');
      case ShareLocalPlanStatus.failed:
        setState(() => _error = result.error ?? 'Freigabe fehlgeschlagen');
    }
  }

  Future<ServerPlanResolution?> _askConflict() =>
      showDialog<ServerPlanResolution>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Konto hat schon einen Plan'),
          content: const Text(
            'Auf dem Server gibt es für dieses Konto bereits einen Plan. '
            'Welcher soll künftig synchronisiert werden?\n\n'
            'Der lokale Plan wird in jedem Fall archiviert und lässt sich '
            'im lokalen Modus wiederherstellen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, ServerPlanResolution.keepServer),
              child: const Text('Serverplan verwenden'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700),
              onPressed: () =>
                  Navigator.pop(context, ServerPlanResolution.uploadLocal),
              child: const Text('Lokalen Plan hochladen'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.cloud_upload, color: Colors.blue),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Mit Server synchronisieren',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _busy ? null : () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 8),
            const Text(
              'Der Plan wird auf den Server geladen und ist danach auf allen '
              'Geräten mit diesem Konto verfügbar. Der lokale Benutzer wird '
              'archiviert und lässt sich im lokalen Modus wiederherstellen.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlCtrl,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Server-URL',
                hintText: 'https://mein-server.de',
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: true,
                    label: Text('Neues Konto'),
                    icon: Icon(Icons.person_add)),
                ButtonSegment(
                    value: false,
                    label: Text('Bestehendes Konto'),
                    icon: Icon(Icons.login)),
              ],
              selected: {_createAccount},
              onSelectionChanged: _busy
                  ? null
                  : (s) => setState(() {
                        _createAccount = s.first;
                        _error = null;
                      }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _userCtrl,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Benutzername auf dem Server',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pwCtrl,
              enabled: !_busy,
              obscureText: true,
              decoration: InputDecoration(
                labelText: _createAccount
                    ? 'Passwort (optional)'
                    : 'Passwort (falls gesetzt)',
                prefixIcon: const Icon(Icons.lock),
              ),
              onSubmitted: (_) => _busy ? null : _share(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: _busy
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Plan freigeben'),
                      onPressed: () => _share(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
