import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:narda/ui/board/board_geometry.dart';
import 'package:narda_core/narda_core.dart';

void main() {
  const Size size = Size(360, 420);

  group('раскладка глазами белых', () {
    final BoardGeometry geometry = BoardGeometry(
      size: size,
      perspective: Player.white,
    );

    test('дом внизу справа, голова вверху справа', () {
      expect(geometry.isBottom(1), isTrue);
      expect(geometry.columnOf(1), 11);
      expect(geometry.isBottom(6), isTrue);
      expect(geometry.columnOf(6), 6);

      expect(geometry.isBottom(24), isFalse);
      expect(geometry.columnOf(24), 11);
    });

    test('голова чёрных — внизу слева', () {
      expect(geometry.isBottom(12), isTrue);
      expect(geometry.columnOf(12), 0);
    });

    test('лоток выброса белых — у их дома, внизу справа', () {
      final Rect tray = geometry.trayRect(Player.white);
      expect(tray.center.dx, greaterThan(geometry.inner.center.dx));
      expect(tray.center.dy, greaterThan(geometry.inner.center.dy));
    });
  });

  group('раскладка глазами чёрных', () {
    final BoardGeometry geometry = BoardGeometry(
      size: size,
      perspective: Player.black,
    );

    test('доска переворачивается: голова чёрных вверху справа', () {
      expect(geometry.isBottom(12), isFalse);
      expect(geometry.columnOf(12), 11);
      expect(geometry.isBottom(24), isTrue);
      expect(geometry.columnOf(24), 0);
    });

    test('дом чёрных (абс. 13–18) внизу справа', () {
      expect(geometry.isBottom(13), isTrue);
      expect(geometry.columnOf(13), 11);
      expect(geometry.isBottom(18), isTrue);
      expect(geometry.columnOf(18), 6);
    });
  });

  test('каждый пункт находится по своей области попадания', () {
    for (final Player perspective in Player.values) {
      final BoardGeometry geometry = BoardGeometry(
        size: size,
        perspective: perspective,
      );
      for (int abs = 1; abs <= Coords.pointCount; abs++) {
        expect(
          geometry.pointAt(geometry.hitRect(abs).center),
          abs,
          reason: 'пункт $abs, перспектива ${perspective.name}',
        );
      }
    }
  });

  test('стопка из 15 шашек умещается в своей половине', () {
    final BoardGeometry geometry = BoardGeometry(
      size: size,
      perspective: Player.white,
    );
    final Rect inner = geometry.inner;
    for (final int abs in <int>[24, 12]) {
      for (int i = 0; i < GameState.checkersPerPlayer; i++) {
        final Offset center = geometry.checkerCenter(
          abs,
          i,
          GameState.checkersPerPlayer,
        );
        expect(inner.inflate(1).contains(center), isTrue);
        expect(
          geometry.pointRect(abs).left <= center.dx &&
              center.dx <= geometry.pointRect(abs).right,
          isTrue,
        );
      }
    }
  });
}
