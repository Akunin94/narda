import 'dice.dart';
import 'game_state.dart';
import 'move.dart';
import 'move_generator.dart';
import 'player.dart';
import 'result.dart';

/// Результат розыгрыша первого хода: по одному кубику каждому,
/// при равенстве бросают заново (§3.2.1).
class OpeningRoll {
  const OpeningRoll({
    required this.white,
    required this.black,
    required this.first,
    required this.rerolls,
  });

  final int white;
  final int black;
  final Player first;

  /// Сколько раз пришлось перебрасывать из-за равенства.
  final int rerolls;

  @override
  String toString() => 'w:$white b:$black -> ${first.name}';
}

/// Ведение одной партии: розыгрыш первого хода, смена очереди, пас, сдача.
/// Само состояние остаётся иммутабельным — [Game] лишь хранит текущее.
class Game {
  Game({
    required DiceSource dice,
    MoveGenerator generator = const MoveGenerator(),
  }) : _dice = dice,
       _generator = generator;

  final DiceSource _dice;
  final MoveGenerator _generator;

  GameState? _state;
  GameResult? _result;
  OpeningRoll? _opening;

  GameState get state {
    final current = _state;
    if (current == null) throw StateError('Call start() first');
    return current;
  }

  GameResult? get result => _result;

  OpeningRoll? get opening => _opening;

  bool get isFinished => _result != null;

  /// Разыгрывает первый ход и расставляет шашки. Первый ходящий бросает
  /// оба кубика заново.
  OpeningRoll start() {
    var rerolls = 0;
    int white;
    int black;
    do {
      white = _dice.rollOne();
      black = _dice.rollOne();
      if (white == black) rerolls++;
    } while (white == black);

    final first = white > black ? Player.white : Player.black;
    final opening = OpeningRoll(
      white: white,
      black: black,
      first: first,
      rerolls: rerolls,
    );
    _opening = opening;
    _state = GameState.initial(first: first, roll: _dice.roll());
    _result = null;
    return opening;
  }

  /// Начинает партию с заданного состояния (реплеи, тесты, P4).
  void restore(GameState state) {
    _state = state;
    _result = state.isFinished ? GameResult.fromState(state) : null;
  }

  /// Максимальные ходы в текущей позиции.
  List<MoveSequence> legalSequences() => _generator.generate(state);

  /// Играет ход целиком и передаёт очередь. Ход обязан быть максимальным.
  void play(MoveSequence sequence) {
    _ensureRunning();
    final legal = legalSequences();
    if (!legal.contains(sequence)) {
      throw ArgumentError.value(sequence, 'sequence', 'Illegal move sequence');
    }
    _advance(state.applySequence(sequence));
  }

  /// Пропуск хода — когда легальных перемещений нет («yurish yo'q»).
  ///
  /// [forced] снимает проверку: в онлайне просроченный по таймеру ход
  /// пропускается принудительно, даже если перемещения были (§6).
  void pass({bool forced = false}) {
    _ensureRunning();
    if (!forced && legalSequences().isNotEmpty) {
      throw StateError('Cannot pass: legal moves are available');
    }
    _advance(state);
  }

  /// Сдача партии игроком [player].
  void resign(Player player) {
    _ensureRunning();
    _result = GameResult.resignation(resigning: player, state: state);
  }

  void _advance(GameState played) {
    if (played.isFinished) {
      _state = played;
      _result = GameResult.fromState(played);
      return;
    }
    _state = played.nextTurn(_dice.roll());
  }

  void _ensureRunning() {
    if (_result != null) throw StateError('Game is already finished');
  }
}
