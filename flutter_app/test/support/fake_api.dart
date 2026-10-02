import 'dart:async';

import 'package:studi_plan/services/api_service.dart';

/// Server im Arbeitsspeicher, der sich offline schalten lässt.
class FakeServer {
  /// Plan des Kontos, für das die Tests arbeiten.
  Map<String, dynamic>? plan;
  bool online = true;
  int saveCalls = 0;

  /// Konten mit Passwort (`null` = ohne Passwort).
  final Map<String, String?> users = {'Alice': null};

  /// Wenn gesetzt, wartet der nächste Abruf, bis der Completer fertig ist.
  Completer<void>? getGate;
}

class FakeApi extends ApiService {
  FakeApi(this.server) : super('http://server.test');

  final FakeServer server;

  @override
  Future<ApiResult<Map<String, dynamic>>> login(
    String username,
    String? password,
  ) async {
    if (!server.online) return const ApiResult(error: 'offline');
    if (!server.users.containsKey(username)) {
      return const ApiResult(error: 'HTTP 404');
    }
    final expected = server.users[username];
    if (expected != null) {
      if (password == null || password.isEmpty) {
        return const ApiResult(requiresPassword: true);
      }
      if (password != expected) {
        return const ApiResult(error: 'Falsches Passwort');
      }
    }
    return ApiResult(data: {'username': username, 'token': 'token'});
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> createUser(
    String username,
    String? password,
  ) async {
    if (!server.online) return const ApiResult(error: 'offline');
    if (server.users.containsKey(username)) {
      return const ApiResult(error: 'Benutzername bereits vergeben');
    }
    server.users[username] =
        password == null || password.isEmpty ? null : password;
    return ApiResult(data: {'username': username, 'token': 'token'});
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> getPlan(
    String username,
    String token,
  ) async {
    final gate = server.getGate;
    server.getGate = null;
    final snapshot = server.plan;
    if (gate != null) await gate.future;
    if (!server.online) return const ApiResult(error: 'offline');
    if (snapshot == null) return const ApiResult(error: 'HTTP 404');
    return ApiResult(data: snapshot);
  }

  @override
  Future<ApiResult<void>> savePlan(
    String username,
    String token,
    Map<String, dynamic> plan,
  ) async {
    server.saveCalls++;
    if (!server.online) return const ApiResult(error: 'offline');
    server.plan = plan;
    return const ApiResult(data: null);
  }
}
