/// Relative paths under Drive appDataFolder for StatMaxxer sync.
abstract final class ShardPaths {
  static const manifest = 'manifest.json';
  static const metaHabits = 'meta/habits.json';
  static const metaSettings = 'meta/settings.json';
  static const metaWishlist = 'meta/wishlist.json';

  static String moneyMonth(int year, int month) =>
      'money/${_y(year)}/${_m(month)}.json';

  static String occurrencesMonth(int year, int month) =>
      'habits/occurrences/${_y(year)}/${_m(month)}.json';

  static String quantityMonth(int year, int month) =>
      'habits/quantity/${_y(year)}/${_m(month)}.json';

  static String _y(int year) => year.toString().padLeft(4, '0');
  static String _m(int month) => month.toString().padLeft(2, '0');

  /// Parses `money/yyyy/MM.json` / habits month paths → (year, month).
  static (int year, int month)? parseYearMonth(String path) {
    final match = RegExp(r'/(\d{4})/(\d{2})\.json$').firstMatch(path);
    if (match == null) return null;
    return (int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  static bool isMeta(String path) => path.startsWith('meta/');
  static bool isMoney(String path) => path.startsWith('money/');
  static bool isOccurrences(String path) =>
      path.startsWith('habits/occurrences/');
  static bool isQuantity(String path) => path.startsWith('habits/quantity/');
}
