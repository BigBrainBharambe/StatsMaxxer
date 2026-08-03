import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stat_maxxer/features/money/presentation/money_format.dart';
import 'package:stat_maxxer/features/settings/domain/app_currency.dart';
import 'package:stat_maxxer/features/settings/presentation/currency_provider.dart';
import 'package:stat_maxxer/features/settings/presentation/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('defaults to INR', () {
    expect(container.read(currencyCodeProvider), 'INR');
    expect(container.read(appCurrencyProvider), AppCurrency.inr);
    expect(container.read(moneyFormatProvider).currencyName, 'INR');
  });

  test('persists currency code and updates formatters', () async {
    await container.read(currencyCodeProvider.notifier).setCurrencyCode('USD');
    expect(container.read(currencyCodeProvider), 'USD');
    expect(prefs.getString('currency_code'), 'USD');
    expect(container.read(moneyFormatProvider).currencyName, 'USD');
    expect(container.read(compactMoneyFormatProvider).currencyName, 'USD');

    // Reload from prefs.
    container.dispose();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    expect(container.read(currencyCodeProvider), 'USD');
  });

  test('unknown stored code falls back to INR', () async {
    await prefs.setString('currency_code', 'ZZZ');
    container.dispose();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    expect(container.read(currencyCodeProvider), 'INR');
  });

  test('moneyFormatFor uses given currency name', () {
    expect(moneyFormatFor('EUR').currencyName, 'EUR');
    expect(compactMoneyFormatFor('GBP').currencyName, 'GBP');
  });
}
