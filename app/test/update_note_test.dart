import 'package:flutter_test/flutter_test.dart';
import 'package:narda/online/min_build.dart';

void main() {
  test('пояснение к обязательному обновлению: строка или по языкам', () {
    expect(updateNote(null, 'ru'), isNull);
    expect(updateNote('  ', 'ru'), isNull);
    expect(updateNote(' Новый онлайн ', 'ru'), 'Новый онлайн');
    const Map<String, String> both = <String, String>{'uz': 'Yangi', 'ru': 'Новое'};
    expect(updateNote(both, 'ru'), 'Новое');
    expect(updateNote(both, 'uz'), 'Yangi');
    expect(updateNote(<String, String>{'uz': 'Yangi'}, 'ru'), 'Yangi', reason: 'нет русского — узбекский');
    expect(updateNote(42, 'ru'), isNull);
  });
}
