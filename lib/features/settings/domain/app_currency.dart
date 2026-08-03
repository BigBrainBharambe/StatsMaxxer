/// Supported display currencies for money amounts across the app.
class AppCurrency {
  const AppCurrency({
    required this.code,
    required this.name,
    required this.symbol,
  });

  final String code;
  final String name;
  final String symbol;

  String get label => '$code ($symbol) — $name';

  static const inr = AppCurrency(
    code: 'INR',
    name: 'Indian Rupee',
    symbol: '₹',
  );
  static const usd = AppCurrency(
    code: 'USD',
    name: 'US Dollar',
    symbol: '\$',
  );
  static const eur = AppCurrency(
    code: 'EUR',
    name: 'Euro',
    symbol: '€',
  );
  static const gbp = AppCurrency(
    code: 'GBP',
    name: 'British Pound',
    symbol: '£',
  );
  static const aud = AppCurrency(
    code: 'AUD',
    name: 'Australian Dollar',
    symbol: 'A\$',
  );
  static const cad = AppCurrency(
    code: 'CAD',
    name: 'Canadian Dollar',
    symbol: 'C\$',
  );
  static const sgd = AppCurrency(
    code: 'SGD',
    name: 'Singapore Dollar',
    symbol: 'S\$',
  );
  static const aed = AppCurrency(
    code: 'AED',
    name: 'UAE Dirham',
    symbol: 'د.إ',
  );
  static const jpy = AppCurrency(
    code: 'JPY',
    name: 'Japanese Yen',
    symbol: '¥',
  );
  static const chf = AppCurrency(
    code: 'CHF',
    name: 'Swiss Franc',
    symbol: 'CHF',
  );

  static const List<AppCurrency> supported = [
    inr,
    usd,
    eur,
    gbp,
    aud,
    cad,
    sgd,
    aed,
    jpy,
    chf,
  ];

  static const defaultCurrency = inr;

  static AppCurrency fromCode(String? code) {
    if (code == null || code.isEmpty) return defaultCurrency;
    for (final c in supported) {
      if (c.code == code) return c;
    }
    return defaultCurrency;
  }
}
