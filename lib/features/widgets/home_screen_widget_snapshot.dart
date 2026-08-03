/// Immutable payload pushed to home-screen widgets (OCR-free, local data only).
class HomeScreenWidgetSnapshot {
  const HomeScreenWidgetSnapshot({
    required this.title,
    required this.habitsLine,
    required this.streakLine,
    required this.moneyLine,
  });

  final String title;
  final String habitsLine;
  final String streakLine;
  final String moneyLine;

  static const empty = HomeScreenWidgetSnapshot(
    title: 'StatMaxxer',
    habitsLine: 'Open the app to sync',
    streakLine: 'Top streak: —',
    moneyLine: 'Net: —',
  );

  /// Builds the habits progress line from done/total counts.
  static String habitsProgressLine({
    required int done,
    required int total,
  }) {
    if (total <= 0) return 'No habits yet';
    return '$done/$total done';
  }

  static String streakLineFor(int topStreak) => 'Top streak: $topStreak';

  static String moneyLineFor(String formattedNet) => 'Net: $formattedNet';
}
