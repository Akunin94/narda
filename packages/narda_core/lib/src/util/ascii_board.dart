import '../game_state.dart';
import '../player.dart';

/// Текстовое представление доски для консольного раннера и отладки тестов.
abstract final class AsciiBoard {
  static const List<int> _topRow = <int>[
    13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,
  ];
  static const List<int> _bottomRow = <int>[
    12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1,
  ];

  /// Рисует доску: верхний ряд — абс. 13..24, нижний — абс. 12..1.
  /// Голова белых (абс. 24) справа сверху, голова чёрных (абс. 12) слева снизу.
  static String render(GameState state) {
    final buffer = StringBuffer()
      ..writeln(_header(_topRow))
      ..writeln(_cells(state, _topRow))
      ..writeln('     ${'-' * 50}')
      ..writeln(_cells(state, _bottomRow))
      ..writeln(_header(_bottomRow))
      ..writeln(
        '  W: pip ${state.pipCount(Player.white)}, '
        'chiqarish ${state.whiteBorneOff}   '
        'B: pip ${state.pipCount(Player.black)}, '
        'chiqarish ${state.blackBorneOff}',
      )
      ..writeln(
        '  yurish: ${state.turn.name}, zarlar: ${state.roll} '
        '${state.remainingDice}',
      );
    return buffer.toString();
  }

  static const int _cellWidth = 4;

  static String _header(List<int> row) =>
      '  abs${_split(row.map((int abs) => abs.toString()))}';

  static String _cells(GameState state, List<int> row) =>
      '     ${_split(row.map((int abs) => _cell(state, abs)))}';

  /// Раскладывает 12 ячеек в две половины доски, разделённые чертой.
  static String _split(Iterable<String> values) {
    final cells = values.map((String v) => v.padLeft(_cellWidth)).join();
    final half = 6 * _cellWidth;
    return '${cells.substring(0, half)} |${cells.substring(half)}';
  }

  static String _cell(GameState state, int abs) {
    final value = state.countAt(abs);
    if (value == 0) return '.';
    return value > 0 ? 'W$value' : 'B${-value}';
  }

  /// Однострочная сводка позиции.
  static String summary(GameState state) =>
      'w ${state.onBoard(Player.white)}+${state.whiteBorneOff} / '
      'b ${state.onBoard(Player.black)}+${state.blackBorneOff}, '
      'pip ${state.pipCount(Player.white)}:${state.pipCount(Player.black)}';
}
