import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/study_plan_provider.dart';
import '../widgets/server_settings_dialog.dart';

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
    if (!provider.localMode && provider.baseUrl.isEmpty) {
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
              backgroundColor: Colors.red.shade700,
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
      if (!mounted) return;
      _resetLoginState();
      await _fetchUsers();
    } catch (e) {
      if (mounted) {
        _showError('Fehler beim Umschalten in lokalen Modus: $e');
      }
    } finally {
      if (mounted) setState(() => _switchingMode = false);
    }
  }

  Future<void> _useServerMode() async {
    setState(() => _switchingMode = true);
    try {
      await context.read<StudyPlanProvider>().leaveLocalMode();
      if (!mounted) return;
      _resetLoginState();
      await _fetchUsers();
    } catch (e) {
      if (mounted) {
        _showError('Fehler beim Umschalten in Server-Modus: $e');
      }
    } finally {
      if (mounted) setState(() => _switchingMode = false);
    }
  }

  void _resetLoginState() {
    setState(() {
      _users = [];
      _fetchError = null;
      _showCreate = false;
      _pendingUser = null;
      _needsPassword = false;
      _switchingMode = false;
      _pwCtrl.clear();
      _newUserCtrl.clear();
      _newPwCtrl.clear();
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
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
                          color: Colors.blue.shade900.withAlpha(100),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade700),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.blue,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Wechsel zum anderen Modus läuft …',
                                style: TextStyle(color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_switchingMode)
                      const SizedBox(height: 16),
                    if (!provider.localMode && provider.baseUrl.isEmpty)
                      _buildNoBanner(),
                    if (!provider.localMode && provider.baseUrl.isEmpty)
                      const SizedBox(height: 16),
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
        color: const Color(0xFF0F172A),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.school, color: Colors.blue, size: 28),
            const SizedBox(width: 10),
            const Text(
              'StudiPlan',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white70),
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
          color: Colors.orange.shade900.withAlpha(100),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade700),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Kein Server konfiguriert. Bitte Einstellungen öffnen oder lokal verwenden.',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          ],
        ),
      );

  Widget _buildLocalModeButton(StudyPlanProvider provider) =>
      OutlinedButton.icon(
        icon: Icon(
          provider.localMode ? Icons.cloud_outlined : Icons.phone_android,
        ),
        label: Text(
          provider.localMode
              ? 'Server verwenden'
              : 'Lokal verwenden (kein Server)',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: const BorderSide(color: Colors.white24),
        ),
        onPressed: provider.isLoading || _switchingMode
            ? null
            : provider.localMode
                ? _useServerMode
                : _useLocally,
      );

  Widget _buildUserListCard(StudyPlanProvider provider, bool isBusy) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                provider.localMode ? 'Lokal anmelden' : 'Anmelden',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                provider.localMode
                    ? 'Wähle einen lokalen Benutzer oder erstelle einen neuen.'
                    : 'Wähle einen Benutzer oder erstelle einen neuen.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (isBusy)
                const Center(child: CircularProgressIndicator())
              else if (_fetchError != null)
                _buildFetchError(_fetchError!)
              else if (_users.isEmpty)
                Text(
                  provider.localMode
                      ? 'Noch keine lokalen Benutzer vorhanden.'
                      : provider.baseUrl.isNotEmpty
                          ? 'Keine Benutzer vorhanden.'
                          : 'Kein Server konfiguriert.',
                  style: const TextStyle(color: Colors.white54),
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
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
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
                  label: Text(
                    provider.localMode
                        ? 'Neuen lokalen Benutzer erstellen'
                        : 'Neuen Benutzer erstellen',
                  ),
                  onPressed: !isBusy &&
                          (provider.localMode || provider.baseUrl.isNotEmpty)
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
          color: Colors.red.shade900.withAlpha(80),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade700),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Server nicht erreichbar: $error\nBitte URL in den Einstellungen prüfen.',
                style: const TextStyle(color: Colors.red, fontSize: 12),
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
                  Text(
                    provider.localMode
                        ? 'Neuen lokalen Benutzer erstellen'
                        : 'Neuen Benutzer erstellen',
                    style: const TextStyle(
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
                  labelText: 'Passwort (optional)',
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
