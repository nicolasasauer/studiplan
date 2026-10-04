import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/study_plan_provider.dart';
import '../services/api_service.dart';
import '../widgets/server_settings_dialog.dart';
import '../theme/app_theme.dart';

/// Anmeldung am Server. Im lokalen Modus öffnet die App direkt den Plan,
/// diese Seite erscheint nur im Servermodus.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  List<String> _users = [];
  bool _loadingUsers = false;
  String? _fetchError;
  bool _showCreate = false;
  String? _pendingUser;
  bool _needsPassword = false;
  bool _switchingMode = false;

  final _pwCtrl = TextEditingController();
  final _newUserCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  bool _obscurePw = true;
  bool _obscureNewPw = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchUsers());
  }

  @override
  void dispose() {
    _pwCtrl.dispose();
    _newUserCtrl.dispose();
    _newPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    final provider = context.read<StudyPlanProvider>();
    if (provider.baseUrl.isEmpty) {
      setState(() {
        _users = [];
        _fetchError =
            'Server-URL nicht konfiguriert. Bitte Einstellungen prüfen.';
      });
      return;
    }

    setState(() {
      _loadingUsers = true;
      _fetchError = null;
    });

    try {
      final result = await provider.getUsersResult();
      if (mounted) {
        setState(() {
          _users = result.users;
          _fetchError = result.error;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _deleteUser(String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Konto löschen?'),
        content: Text(
          'Soll das Konto "$username" unwiderruflich gelöscht werden? '
          'Alle Daten gehen dabei verloren.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.cs.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<StudyPlanProvider>();
    final err = await provider.deleteUserByName(username);
    if (!mounted) return;

    if (err != null) {
      _showError('Fehler: $err');
    } else {
      setState(() => _users.remove(username));
    }
  }

  Future<void> _loginUser(String username) async {
    final provider = context.read<StudyPlanProvider>();
    final result = await provider.login(username, null);
    if (!mounted) return;

    if (result == 'REQUIRES_PASSWORD') {
      setState(() {
        _pendingUser = username;
        _needsPassword = true;
        _pwCtrl.clear();
      });
    } else if (result != null) {
      _showError(result);
    }
  }

  Future<void> _submitPassword() async {
    if (_pendingUser == null) return;
    final provider = context.read<StudyPlanProvider>();
    final result = await provider.login(_pendingUser!, _pwCtrl.text);
    if (!mounted) return;
    if (result != null && result != 'REQUIRES_PASSWORD') _showError(result);
  }

  Future<void> _createUser() async {
    final name = _newUserCtrl.text.trim();
    if (name.isEmpty) {
      _showError('Benutzername darf nicht leer sein');
      return;
    }

    final provider = context.read<StudyPlanProvider>();
    final pw = _newPwCtrl.text;
    final result = await provider.createUser(name, pw.isEmpty ? null : pw);
    if (!mounted) return;
    if (result != null) _showError(result);
  }

  Future<void> _useLocally() async {
    setState(() => _switchingMode = true);
    try {
      await context.read<StudyPlanProvider>().enterLocalMode();
    } catch (e) {
      if (mounted) {
        _showError('Fehler beim Umschalten in lokalen Modus: $e');
      }
    } finally {
      if (mounted) setState(() => _switchingMode = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: context.cs.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudyPlanProvider>();
    final isBusy = provider.isLoading || _loadingUsers;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_switchingMode)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.tone(Colors.blue).withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.tone(Colors.blue).withAlpha(120)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  context.tone(Colors.blue),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Wechsel zum anderen Modus läuft …',
                                style: TextStyle(color: context.tone(Colors.blue)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_switchingMode)
                      const SizedBox(height: 16),
                    if (provider.baseUrl.isEmpty) _buildNoBanner(),
                    if (provider.baseUrl.isEmpty) const SizedBox(height: 16),
                    if (_needsPassword && _pendingUser != null)
                      _buildPasswordCard(provider)
                    else if (_showCreate)
                      _buildCreateCard(provider)
                    else
                      _buildUserListCard(provider, isBusy),
                    const SizedBox(height: 12),
                    _buildLocalModeButton(provider),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) => Container(
        color: context.cs.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.school, color: context.tone(Colors.blue), size: 28),
            const SizedBox(width: 10),
            Text(
              'StudiPlan',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: context.cs.onSurface,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.settings, color: context.cs.onSurfaceVariant),
              tooltip: 'Server-Einstellungen',
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (_) => const ServerSettingsDialog(),
                );
                _fetchUsers();
              },
            ),
          ],
        ),
      );

  Widget _buildNoBanner() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.tone(Colors.orange).withAlpha(30),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.tone(Colors.orange).withAlpha(120)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: context.tone(Colors.orange)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Kein Server konfiguriert. Bitte Einstellungen öffnen oder lokal verwenden.',
                style: TextStyle(color: context.tone(Colors.orange)),
              ),
            ),
          ],
        ),
      );

  Widget _buildLocalModeButton(StudyPlanProvider provider) =>
      OutlinedButton.icon(
        icon: const Icon(Icons.phone_android),
        label: const Text('Lokal verwenden (kein Server)'),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.cs.onSurfaceVariant,
          side: BorderSide(color: context.cs.outline),
        ),
        onPressed: provider.isLoading || _switchingMode ? null : _useLocally,
      );

  Widget _buildUserListCard(StudyPlanProvider provider, bool isBusy) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Anmelden',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Wähle einen Benutzer oder erstelle einen neuen.',
                style: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (isBusy)
                const Center(child: CircularProgressIndicator())
              else if (_fetchError != null)
                _buildFetchError(_fetchError!)
              else if (_users.isEmpty)
                Text(
                  provider.baseUrl.isNotEmpty
                      ? 'Keine Benutzer vorhanden.'
                      : 'Kein Server konfiguriert.',
                  style: TextStyle(color: context.cs.onSurfaceVariant),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final u = _users[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade700,
                        child: Text(
                          u[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(u),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: context.tone(Colors.red),
                              size: 20,
                            ),
                            tooltip: 'Konto löschen',
                            onPressed: isBusy ? null : () => _deleteUser(u),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                      onTap: isBusy ? null : () => _loginUser(u),
                    );
                  },
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person_add),
                  label: const Text('Neuen Benutzer erstellen'),
                  onPressed: !isBusy && provider.baseUrl.isNotEmpty
                      ? () => setState(() => _showCreate = true)
                      : null,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildFetchError(String error) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.tone(Colors.red).withAlpha(30),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.tone(Colors.red).withAlpha(120)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: context.tone(Colors.red), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Server nicht erreichbar: $error\nBitte URL in den Einstellungen prüfen.',
                style: TextStyle(color: context.tone(Colors.red), fontSize: 12),
              ),
            ),
          ],
        ),
      );

  Widget _buildPasswordCard(StudyPlanProvider provider) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() {
                      _needsPassword = false;
                      _pendingUser = null;
                    }),
                  ),
                  Text(
                    'Passwort für $_pendingUser',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pwCtrl,
                obscureText: _obscurePw,
                decoration: InputDecoration(
                  labelText: 'Passwort',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePw ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscurePw = !_obscurePw),
                  ),
                ),
                onSubmitted: (_) => _submitPassword(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _submitPassword,
                        child: const Text('Anmelden'),
                      ),
              ),
            ],
          ),
        ),
      );

  Widget _buildCreateCard(StudyPlanProvider provider) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() => _showCreate = false),
                  ),
                  const Text(
                    'Neuen Benutzer erstellen',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newUserCtrl,
                decoration: const InputDecoration(labelText: 'Benutzername *'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPwCtrl,
                obscureText: _obscureNewPw,
                decoration: InputDecoration(
                  labelText: 'Passwort * (mindestens '
                      '${ApiService.minPasswordLength} Zeichen)',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPw ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscureNewPw = !_obscureNewPw),
                  ),
                ),
                onSubmitted: (_) => _createUser(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _createUser,
                        child: const Text('Erstellen & Anmelden'),
                      ),
              ),
            ],
          ),
        ),
      );
}
