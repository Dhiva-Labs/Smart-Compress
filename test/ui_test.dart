import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_compress/app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpApp(WidgetTester tester,
      {Size logicalSize = const Size(360, 800)}) async {
    tester.view.physicalSize = logicalSize * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: SmartCompressApp()));
    await tester.pumpAndSettle();
  }

  testWidgets('home renders on a phone without overflow', (tester) async {
    await pumpApp(tester);
    expect(find.text('Image Compressor'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home renders on desktop without overflow', (tester) async {
    await pumpApp(tester, logicalSize: const Size(1280, 800));
    expect(find.text('Video Compressor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme toggle switches dark and light', (tester) async {
    await pumpApp(tester);
    final ctx = tester.element(find.text('Image Compressor'));
    final before = Theme.of(ctx).brightness;
    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();
    final after =
        Theme.of(tester.element(find.text('Image Compressor'))).brightness;
    expect(after, isNot(before));
  });

  testWidgets('image screen options fit a phone width', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Image Compressor'));
    await tester.pumpAndSettle();
    expect(find.text('Presets'), findsOneWidget);
    // Options stack vertically on phones; scrolling must reach the switch.
    await tester.scrollUntilVisible(
        find.text('Remove metadata (EXIF)'), 200);
    expect(tester.takeException(), isNull);
  });

  testWidgets('archive screen fits a phone width', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(find.text('Create archive'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('video screen fits a phone width', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Video Compressor'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('compress button is always visible without scrolling',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Image Compressor'));
    await tester.pumpAndSettle();
    // Sticky bottom bar: visible immediately even though options overflow.
    expect(find.text('Compress 0 files'), findsOneWidget);
  });
}
