import 'study_plan.dart';

/// Lokaler Benutzer samt Plan, der nach der Freigabe zur Synchronisierung
/// archiviert wurde. Lässt sich im lokalen Modus wiederherstellen.
class ArchivedLocalPlan {
  final String id;
  final String username;
  final String? passwordHash;
  final DateTime archivedAt;

  /// Konto auf dem Server, für das der Plan freigegeben wurde.
  final String? sharedAs;
  final StudyPlan plan;

  const ArchivedLocalPlan({
    required this.id,
    required this.username,
    this.passwordHash,
    required this.archivedAt,
    this.sharedAs,
    required this.plan,
  });

  factory ArchivedLocalPlan.fromJson(Map<String, dynamic> json) {
    final rawPlan = json['plan'];
    return ArchivedLocalPlan(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      passwordHash: json['passwordHash'] as String?,
      archivedAt: DateTime.tryParse(json['archivedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      sharedAs: json['sharedAs'] as String?,
      plan: rawPlan is Map
          ? StudyPlan.fromJson(Map<String, dynamic>.from(rawPlan))
          : StudyPlan(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'passwordHash': passwordHash,
        'archivedAt': archivedAt.toUtc().toIso8601String(),
        'sharedAs': sharedAs,
        'plan': plan.toJson(),
      };
}
