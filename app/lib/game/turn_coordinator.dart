import 'package:narda_core/narda_core.dart';

/// Внешний ведущий партии — второй шов сетевой игры рядом с `Opponent` (§6).
///
/// В оффлайне его нет: очередь первого хода и все броски берутся из локального
/// [DiceSource]. В онлайне партию ведут двое, поэтому и розыгрыш первого хода,
/// и каждый бросок приходится согласовывать, а собранный ход — публиковать.
/// Доска об этом не знает: она лишь ждёт `Future`.
abstract interface class TurnCoordinator {
  /// Позиция, с которой начинается партия: свежая раздача или восстановленная
  /// реплеем журнала после реконнекта.
  ///
  /// Бросок очередного хода в этой позиции — заглушка: его отдельно вернёт
  /// [roll].
  Future<GameState> opening();

  /// Согласованный бросок очередного хода. Активная сторона бросает сама и
  /// публикует, пассивная — ждёт публикации соперника.
  Future<DiceRoll> roll(GameState state);

  /// Подтверждённый локальный ход уходит сопернику. Пустая последовательность —
  /// пропуск: ходов не было или ход просрочен по таймеру.
  Future<void> publish(GameState before, MoveSequence sequence);

  /// Локальный игрок сдался.
  Future<void> publishResign();

  /// Всё, что происходит с партией помимо ходов.
  Stream<MatchSignal> get signals;
}

/// Событие от внешней стороны, меняющее ход партии.
sealed class MatchSignal {
  const MatchSignal();
}

/// Позиция пересобрана реплеем журнала — доска перезапускает ход с неё (§6).
class ResyncSignal extends MatchSignal {
  const ResyncSignal(this.state);

  final GameState state;
}

/// Партия закончилась не на доске: сдача соперника, тайм-аут, разрыв связи.
class FinishSignal extends MatchSignal {
  const FinishSignal(this.result);

  final GameResult result;
}

/// Партия аннулирована: восстановить общее состояние не удалось.
class AbortSignal extends MatchSignal {
  const AbortSignal(this.reason);

  final MatchAbortReason reason;
}

/// Почему партия аннулирована.
///
/// Ушедший соперник сюда не попадает: его отсутствие не рвёт партию, а даёт
/// право забрать победу через 60 секунд (§6).
enum MatchAbortReason {
  /// Ход соперника нелегален и реплей журнала не спасает (§6).
  desync,

  /// Сеть или бэкенд отказали.
  connection,
}
