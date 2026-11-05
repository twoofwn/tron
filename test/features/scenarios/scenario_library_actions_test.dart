import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tron/app/theme/app_theme.dart';
import 'package:tron/features/scenarios/data/scenario_repository.dart';
import 'package:tron/features/scenarios/models/scenario.dart';
import 'package:tron/features/scenarios/presentation/scenario_library_screen.dart';

/// Chờ các bước ghi file thật (mỗi bước chỉ chạy tiếp sau một lần pump).
Future<void> settleIo(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

void main() {
  late Directory documents;
  late ScenarioRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    documents = await Directory.systemTemp.createTemp('tron-library-');
  });

  tearDown(() async {
    repository.dispose();
    await documents.delete(recursive: true);
  });

  /// Kho kịch bản thật (dữ liệu mẫu trong assets) trên màn điện thoại 360 px.
  Future<void> open(WidgetTester tester) async {
    // Đủ cao để thấy cả lưới âm nền mà không phải cuộn.
    tester.view.physicalSize = const Size(360, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repository = ScenarioRepository(documentsDirectory: () async => documents);
    await tester.runAsync(repository.load);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.create(Brightness.dark),
        home: ScenarioLibraryScreen(
          repository: repository,
          initialSelection: const ScenarioSelection(
            scenarioId: 'boss-server',
            backgroundId: 'office',
          ),
          onSelectionChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the Add tile stays on one line on a phone', (tester) async {
    await open(tester);
    final label = find.text('Thêm');
    expect(label, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(label);
    expect(paragraph.didExceedMaxLines, isFalse);
    // Một dòng chữ cỡ 13 cao chưa tới 20 px.
    expect(tester.getSize(label).height, lessThan(20));
    // Icon nằm trên chữ như các ô âm nền khác.
    final icon = find.byIcon(Icons.add).last;
    expect(tester.getCenter(icon).dy, lessThan(tester.getCenter(label).dy));
  });

  testWidgets('every scenario card has edit and delete actions', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byTooltip('Tuỳ chọn Sếp cần file gấp'));
    await tester.pumpAndSettle();
    expect(find.text('Sửa'), findsOneWidget);
    expect(find.text('Tạo bản sao'), findsOneWidget);
    expect(find.text('Xoá'), findsOneWidget);
  });

  testWidgets('deleting a sample hides it until it is shown again', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Sếp cần file gấp'), findsOneWidget);
    await tester.tap(find.byTooltip('Tuỳ chọn Sếp cần file gấp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xoá'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Combo đang dùng vẫn gọi được'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Xoá'));
    await settleIo(tester);
    await tester.pumpAndSettle();

    expect(find.text('Sếp cần file gấp'), findsNothing);
    // Combo đang dùng kịch bản này vẫn tìm thấy nó.
    expect(repository.findScenario('boss-server'), isNotNull);
    final restore = find.text('Hiện lại 1 kịch bản mẫu đã xoá');
    expect(restore, findsOneWidget);

    await tester.tap(restore);
    await settleIo(tester);
    await tester.pumpAndSettle();
    expect(find.text('Sếp cần file gấp'), findsOneWidget);
    expect(restore, findsNothing);
  });

  testWidgets('an edited sample can be restored from its menu', (tester) async {
    await open(tester);
    final sample = repository.findScenario('mother-urgent')!;
    await tester.runAsync(
      () => repository.saveUserScenario(
        sample.copyWith(title: 'Mẹ đã sửa', source: ScenarioSource.user),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mẹ đã sửa'), findsOneWidget);

    await tester.tap(find.byTooltip('Tuỳ chọn Mẹ đã sửa'));
    await tester.pumpAndSettle();
    expect(find.text('Tạo bản sao'), findsNothing);
    await tester.tap(find.text('Khôi phục bản gốc'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Khôi phục'));
    await settleIo(tester);
    await tester.pumpAndSettle();
    expect(find.text('Mẹ đã sửa'), findsNothing);
    expect(find.text(sample.title), findsOneWidget);
  });
}
