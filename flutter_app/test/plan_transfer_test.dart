import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studi_plan/widgets/plan_transfer.dart';

void main() {
  String? clipboard;

  setUp(() {
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          switch (call.method) {
            case 'Clipboard.setData':
              clipboard = (call.arguments as Map)['text'] as String?;
              return null;
            case 'Clipboard.getData':
              return clipboard == null ? null : {'text': clipboard};
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  /// Pumps a button that runs [open] and stores its result in [result].
  Future<void> pumpOpener<T>(
    WidgetTester tester,
    Future<T?> Function(BuildContext) open,
    void Function(T?) result,
  ) {
    return tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result(await open(context)),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  group('export options', () {
    testWidgets('offers save, share and copy on phones', (tester) async {
      ExportAction? picked;
      await pumpOpener<ExportAction>(
        tester,
        (c) => showExportOptions(c, canShare: true),
        (r) => picked = r,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('export-save')), findsOneWidget);
      expect(find.byKey(const Key('export-share')), findsOneWidget);
      expect(find.byKey(const Key('export-copy')), findsOneWidget);

      await tester.tap(find.byKey(const Key('export-copy')));
      await tester.pumpAndSettle();
      expect(picked, ExportAction.copyText);
    });

    testWidgets('hides sharing where there is no share menu', (tester) async {
      ExportAction? picked;
      await pumpOpener<ExportAction>(
        tester,
        (c) => showExportOptions(c, canShare: false),
        (r) => picked = r,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('export-share')), findsNothing);
      await tester.tap(find.byKey(const Key('export-save')));
      await tester.pumpAndSettle();
      expect(picked, ExportAction.saveFile);
    });

    testWidgets('dismissing picks nothing', (tester) async {
      ExportAction? picked = ExportAction.share;
      await pumpOpener<ExportAction>(
        tester,
        (c) => showExportOptions(c, canShare: true),
        (r) => picked = r,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(picked, isNull);
    });
  });

  testWidgets('import options offer file and pasted text', (tester) async {
    ImportAction? picked;
    await pumpOpener<ImportAction>(
      tester,
      showImportOptions,
      (r) => picked = r,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ersetzt den aktuellen'), findsOneWidget);
    await tester.tap(find.byKey(const Key('import-paste')));
    await tester.pumpAndSettle();
    expect(picked, ImportAction.pasteText);
  });

  group('PasteImportDialog', () {
    Future<void> openDialog(
      WidgetTester tester,
      void Function(String?) result,
    ) {
      return pumpOpener<String>(
        tester,
        (c) => showDialog<String>(
          context: c,
          builder: (_) => const PasteImportDialog(),
        ),
        result,
      );
    }

    testWidgets('starts with plan JSON from the clipboard', (tester) async {
      clipboard = '  {"planName": "Info"}\n';
      String? text;
      await openDialog(tester, (r) => text = r);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('paste-import')));
      await tester.pumpAndSettle();
      expect(text, '{"planName": "Info"}');
    });

    testWidgets('ignores clipboard text that is not JSON', (tester) async {
      clipboard = 'https://example.com';
      await openDialog(tester, (_) {});
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const Key('paste-field')),
      );
      expect(field.controller!.text, isEmpty);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('paste-import')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('takes typed text and cancel returns nothing', (tester) async {
      String? text = 'unchanged';
      await openDialog(tester, (r) => text = r);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('paste-field')), '{}');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('paste-import')))
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(text, isNull);
    });
  });
}
