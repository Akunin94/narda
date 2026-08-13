import 'package:narda_core/narda_core.dart';
import 'package:test/test.dart';

void main() {
  group('Coords', () {
    test('белые: собственная нумерация совпадает с абсолютной', () {
      for (var n = 1; n <= 24; n++) {
        expect(Coords.toAbsolute(Player.white, n), n);
        expect(Coords.toOwn(Player.white, n), n);
      }
    });

    test('чёрные: сдвиг на полкруга, перевод — инволюция', () {
      expect(Coords.toAbsolute(Player.black, 24), 12);
      expect(Coords.toAbsolute(Player.black, 1), 13);
      expect(Coords.toAbsolute(Player.black, 6), 18);
      for (var n = 1; n <= 24; n++) {
        expect(Coords.toOwn(Player.black, Coords.toAbsolute(Player.black, n)), n);
      }
    });

    test('перевод биективен для обоих игроков', () {
      for (final player in Player.values) {
        final images = <int>{
          for (var n = 1; n <= 24; n++) Coords.toAbsolute(player, n),
        };
        expect(images.length, 24);
        expect(images.reduce((int a, int b) => a < b ? a : b), 1);
        expect(images.reduce((int a, int b) => a > b ? a : b), 24);
      }
    });

    test('головы и дома', () {
      expect(Coords.headAbs(Player.white), 24);
      expect(Coords.headAbs(Player.black), 12);
      for (var abs = 1; abs <= 6; abs++) {
        expect(Coords.isHomeAbs(Player.white, abs), isTrue);
        expect(Coords.isHomeAbs(Player.black, abs), isFalse);
      }
      for (var abs = 13; abs <= 18; abs++) {
        expect(Coords.isHomeAbs(Player.black, abs), isTrue);
        expect(Coords.isHomeAbs(Player.white, abs), isFalse);
      }
    });

    test('поворот маски на полкруга — инволюция', () {
      for (var index = 0; index < 24; index++) {
        final mask = 1 << index;
        expect(Rules.rotateHalf(Rules.rotateHalf(mask)), mask);
        expect(Rules.rotateHalf(mask), 1 << ((index + 12) % 24));
      }
    });
  });
}
