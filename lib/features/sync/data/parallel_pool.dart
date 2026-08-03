import 'dart:async';
import 'dart:collection';

/// Runs async work with a bounded concurrency pool.
Future<List<T>> runBoundedParallel<T>(
  Iterable<Future<T> Function()> tasks, {
  int concurrency = 4,
}) async {
  if (concurrency < 1) {
    throw ArgumentError.value(concurrency, 'concurrency', 'must be >= 1');
  }
  final queue = Queue<Future<T> Function()>.of(tasks);
  if (queue.isEmpty) return const [];

  final results = <T>[];
  final errors = <Object>[];
  var active = 0;
  final done = Completer<void>();

  void pump() {
    while (active < concurrency && queue.isNotEmpty) {
      final task = queue.removeFirst();
      active++;
      () async {
        try {
          results.add(await task());
        } catch (e) {
          errors.add(e);
        } finally {
          active--;
          if (queue.isEmpty && active == 0) {
            if (!done.isCompleted) done.complete();
          } else {
            pump();
          }
        }
      }();
    }
    if (queue.isEmpty && active == 0 && !done.isCompleted) {
      done.complete();
    }
  }

  pump();
  await done.future;
  if (errors.isNotEmpty) {
    throw errors.first;
  }
  return results;
}
