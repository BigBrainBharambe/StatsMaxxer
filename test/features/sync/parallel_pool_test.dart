import 'package:flutter_test/flutter_test.dart';
import 'package:stat_maxxer/features/sync/data/parallel_pool.dart';

void main() {
  test('runs tasks with bounded concurrency', () async {
    var peak = 0;
    var active = 0;
    final tasks = List.generate(8, (i) {
      return () async {
        active++;
        if (active > peak) peak = active;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        active--;
        return i;
      };
    });

    final results = await runBoundedParallel(tasks, concurrency: 3);
    expect(results, hasLength(8));
    expect(peak, lessThanOrEqualTo(3));
    expect(peak, greaterThan(0));
  });
}
