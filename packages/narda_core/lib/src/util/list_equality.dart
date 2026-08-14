/// Поэлементное сравнение списков.
///
/// Ядро не зависит ни от Flutter, ни от `package:collection`, а `==` у
/// списков сравнивает ссылки, — поэтому у каждого значения с полем-списком
/// (позиция, ход, запись журнала) был свой одинаковый цикл.
bool sameItems<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
