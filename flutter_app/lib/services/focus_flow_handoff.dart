import 'dart:convert';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../models/semester.dart';
import '../models/study_plan.dart';

/// Hands a semester over to Focus Flow, which takes its lectures over as
/// subjects.
///
/// Where Focus Flow registers its `focusflow://` scheme (Android, and the
/// Store package on Windows), the semester travels in a link that opens
/// Focus Flow directly. Without Focus Flow, or elsewhere, the caller falls
/// back to the clipboard ([StudyPlan.semesterExportJson]).
abstract final class FocusFlowHandoff {
  /// Opens [link] in Focus Flow; false when Focus Flow is not installed.
  /// Replaced in tests, which have no platform to launch anything on.
  static Future<bool> Function(Uri link) openLink = _launch;

  static Future<bool> _launch(Uri link) async {
    if (!Platform.isAndroid && !Platform.isWindows) return false;
    try {
      if (!await canLaunchUrl(link)) return false;
      return await launchUrl(link, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }

  /// `focusflow://studiplan?plan=…`: the semester in StudiPlan's plan
  /// layout, base64url-encoded, with only what Focus Flow reads - the
  /// link has to stay short enough for a Windows command line.
  static Uri link(StudyPlan plan, Semester semester) {
    final json = jsonEncode({
      'planName': plan.planName,
      'semesters': [
        {
          'number': semester.number,
          'season': semester.season,
          'lectures': [
            for (final l in semester.lectures)
              {'name': l.name, 'color': l.color, 'passed': l.passed},
          ],
        },
      ],
    });
    return Uri(
      scheme: 'focusflow',
      host: 'studiplan',
      queryParameters: {
        'plan': base64Url.encode(utf8.encode(json)).replaceAll('=', ''),
      },
    );
  }
}
