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
      // Android: straight to launchUrl, which reports a missing Focus Flow
      // itself. canLaunchUrl depends on package visibility and wrongly said
      // "not installed" while the <queries> entry lacked the host. Windows:
      // ask first, or an unknown scheme pops the "find an app" dialog.
      if (Platform.isWindows && !await canLaunchUrl(link)) return false;
      return await launchUrl(link, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }

  /// `focusflow://studiplan?plan=…`: the semester in StudiPlan's plan
  /// layout, base64url-encoded, with only what Focus Flow reads (name,
  /// colour, passed, exam date) - the link has to stay short enough for a
  /// Windows command line.
  static Uri link(StudyPlan plan, Semester semester) => _link(plan, [semester]);

  /// The same for every semester of [plan], for Focus Flow's "Aus StudiPlan
  /// übernehmen": Focus Flow offers the current one and lets the user pick.
  /// The parking lot stays out - nothing there is being studied yet.
  static Uri planLink(StudyPlan plan) => _link(plan, plan.semesters);

  static Uri _link(StudyPlan plan, List<Semester> semesters) {
    final json = jsonEncode({
      'planName': plan.planName,
      'semesters': [
        for (final semester in semesters)
          {
            'number': semester.number,
            'season': semester.season,
            'lectures': [
              for (final l in semester.lectures)
                {
                  'name': l.name,
                  'color': l.color,
                  'passed': l.passed,
                  if (l.examDate != null) 'examDate': l.examDate,
                },
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

  /// Focus Flow asking for the plan: `studiplan://export`. The answer always
  /// goes to Focus Flow's own scheme, never to an address in the request.
  static bool isExportRequest(Uri uri) =>
      uri.scheme == 'studiplan' && uri.host == 'export';
}
