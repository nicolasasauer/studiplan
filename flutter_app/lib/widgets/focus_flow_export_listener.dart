import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/study_plan_provider.dart';
import '../services/focus_flow_handoff.dart';

/// Links that open the app, on the platforms StudiPlan registers its
/// `studiplan://` scheme on: Android (intent filter) and Windows (the Store
/// package's protocol activation).
Stream<Uri> platformAppLinks() => Platform.isAndroid || Platform.isWindows
    ? AppLinks().uriLinkStream
    : const Stream<Uri>.empty();

/// Answers Focus Flow's `studiplan://export`: sends the open plan straight
/// back with [FocusFlowHandoff.planLink], where Focus Flow lets the user
/// pick the lectures to take over.
///
/// A request that arrives before a plan is open (still loading, or on the
/// login screen) waits and is answered as soon as there is one.
class FocusFlowExportListener extends StatefulWidget {
  const FocusFlowExportListener({
    super.key,
    required this.links,
    required this.child,
  });

  final Stream<Uri> links;
  final Widget child;

  @override
  State<FocusFlowExportListener> createState() =>
      _FocusFlowExportListenerState();
}

class _FocusFlowExportListenerState extends State<FocusFlowExportListener> {
  StreamSubscription<Uri>? _subscription;
  StudyPlanProvider? _provider;
  bool _pending = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget.links.listen(_onLink);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<StudyPlanProvider>();
    if (!identical(provider, _provider)) {
      _provider?.removeListener(_trySend);
      _provider = provider..addListener(_trySend);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _provider?.removeListener(_trySend);
    super.dispose();
  }

  void _onLink(Uri uri) {
    if (!FocusFlowHandoff.isExportRequest(uri)) return;
    _pending = true;
    _lastToast = null;
    _trySend();
  }

  Future<void> _trySend() async {
    final provider = _provider;
    if (!_pending || _sending || provider == null || !mounted) return;
    // Still starting: the plan follows in a moment, no need to say so.
    if (!provider.isInitialized) return;
    if (!provider.isLoggedIn) {
      _toast('Focus Flow möchte den Plan – er wird gesendet, sobald er '
          'geöffnet ist.');
      return;
    }
    final plan = provider.plan;
    if (plan.semesters.every((s) => s.lectures.isEmpty)) {
      _pending = false;
      _toast('Für Focus Flow gibt es nichts zu senden: '
          'noch keine Veranstaltung in einem Semester.');
      return;
    }
    _pending = false;
    _sending = true;
    try {
      final sent =
          await FocusFlowHandoff.openLink(FocusFlowHandoff.planLink(plan));
      _toast(sent
          ? 'Plan an Focus Flow gesendet'
          : 'Focus Flow ließ sich nicht öffnen.');
    } finally {
      _sending = false;
    }
  }

  String? _lastToast;

  void _toast(String text) {
    // The "waiting" note would otherwise repeat with every provider change.
    if (!mounted || text == _lastToast) return;
    _lastToast = text;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
