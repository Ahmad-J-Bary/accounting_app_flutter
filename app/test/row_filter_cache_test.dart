import 'package:accounting_app_flutter/ui/table/row_filter_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reuses the cached rows while the key does not change', () {
    final cache = RowFilterCache<int>();
    var calls = 0;
    const source = [1, 2];

    final first = cache.resolve(('ابحث', true, source), () {
      calls++;
      return const [1, 2];
    });
    final second = cache.resolve(('ابحث', true, source), () {
      calls++;
      return const [3];
    });

    expect(identical(first, second), isTrue);
    expect(calls, 1);
    expect(cache.computeCount, 1);
    expect(cache.matches(('ابحث', true, source)), isTrue);
  });

  test('recomputes the rows when the key changes', () {
    final cache = RowFilterCache<int>();

    final first = cache.resolve(('a', 1), () => const [1]);
    final second = cache.resolve(('b', 1), () => const [2]);

    expect(identical(first, second), isFalse);
    expect(cache.computeCount, 2);
  });

  test('treats a new source list as a different key', () {
    final cache = RowFilterCache<int>();
    final source = [1, 2, 3];

    final first = cache.resolve(('a', source), () => const [1]);
    final second = cache.resolve(('a', [1, 2, 3]), () => const [2]);

    expect(identical(first, second), isFalse);
    expect(cache.computeCount, 2);
  });

  test('clear drops the cached rows', () {
    final cache = RowFilterCache<int>();
    cache.resolve(('a', 1), () => const [1]);
    cache.clear();

    expect(cache.matches(('a', 1)), isFalse);
    cache.resolve(('a', 1), () => const [2]);
    expect(cache.computeCount, 2);
  });
}
