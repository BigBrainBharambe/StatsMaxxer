import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_currency.dart';
import 'theme_provider.dart';

final currencyCodeProvider =
    NotifierProvider<CurrencyCodeNotifier, String>(CurrencyCodeNotifier.new);

final appCurrencyProvider = Provider<AppCurrency>((ref) {
  return AppCurrency.fromCode(ref.watch(currencyCodeProvider));
});

class CurrencyCodeNotifier extends Notifier<String> {
  static const _key = 'currency_code';

  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AppCurrency.fromCode(prefs.getString(_key)).code;
  }

  Future<void> setCurrencyCode(String code) async {
    final currency = AppCurrency.fromCode(code);
    state = currency.code;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, currency.code);
  }

  Future<void> setCurrency(AppCurrency currency) =>
      setCurrencyCode(currency.code);
}
