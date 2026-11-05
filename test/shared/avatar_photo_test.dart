import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tron/core/services/file_service.dart';
import 'package:tron/features/combo/models/combo_model.dart';
import 'package:tron/features/home/widgets/combo_card.dart';
import 'package:tron/shared/enums/call_interface.dart';
import 'package:tron/shared/widgets/avatar_photo.dart';

/// PNG 1×1 điểm ảnh hợp lệ.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

class _Files extends FileService {
  _Files(this.files);
  final Map<String, Uint8List> files;
  @override
  Future<Uint8List> readMedia(String path) async =>
      files[path] ?? (throw StateError('missing $path'));
}

ComboModel _combo({String? avatarPath}) => ComboModel(
  id: 'c1',
  name: 'Mẹ gọi về nhà',
  scenarioId: 'mother',
  callInterface: CallInterface.phone,
  createdAt: DateTime(2026),
  avatarPath: avatarPath,
);

Future<void> _pumpCard(WidgetTester tester, ComboModel combo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fileServiceProvider.overrideWithValue(_Files({'media:face.png': _png})),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ComboCard(combo: combo, isSelected: false, onTap: () {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('Image type is read from the file content', () {
    expect(FileService.imageExtension(_png), 'png');
    expect(
      FileService.imageExtension(
        Uint8List.fromList([0xFF, 0xD8, 0xFF, ...List.filled(12, 0)]),
      ),
      'jpg',
    );
    expect(FileService.imageExtension(Uint8List(16)), isNull);
    expect(FileService.mediaPathPattern.hasMatch('media:ab-12.png'), isTrue);
    expect(FileService.isImagePath('media:ab-12.jpg'), isTrue);
  });

  testWidgets('Combo card shows the caller photo', (tester) async {
    await _pumpCard(tester, _combo(avatarPath: 'media:face.png'));
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('M'), findsNothing);
  });

  testWidgets('Combo card falls back to the initial without a photo', (
    tester,
  ) async {
    await _pumpCard(tester, _combo());
    expect(find.byType(Image), findsNothing);
    expect(find.text('M'), findsOneWidget);
  });

  testWidgets('A missing photo file falls back to the initial', (tester) async {
    await _pumpCard(tester, _combo(avatarPath: 'media:gone.jpg'));
    expect(find.byType(Image), findsNothing);
    expect(find.text('M'), findsOneWidget);
  });

  testWidgets('AvatarPhoto clips the photo to the requested size', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fileServiceProvider.overrideWithValue(
            _Files({'media:face.png': _png}),
          ),
        ],
        child: const MaterialApp(
          home: Center(
            child: AvatarPhoto(
              path: 'media:face.png',
              size: 80,
              fallback: Text('?'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ClipOval), findsOneWidget);
    expect(tester.getSize(find.byType(ClipOval)), const Size(80, 80));
    expect(find.text('?'), findsNothing);
  });
}
