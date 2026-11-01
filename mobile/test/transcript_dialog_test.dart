import 'package:clipforge_mobile/transcript_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'subtitle correction validates text and returns trimmed correction',
    (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await editTranscriptText(context, 'wrong word');
                },
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(find.text('Teks tidak boleh kosong.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '  corrected words  ');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(result, 'corrected words');
      expect(tester.takeException(), isNull);
    },
  );
}
