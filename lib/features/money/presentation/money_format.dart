import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../settings/presentation/currency_provider.dart';

/// Formats amounts with the user-selected currency (Settings).
NumberFormat moneyFormatFor(String currencyCode) =>
    NumberFormat.simpleCurrency(name: currencyCode);

NumberFormat compactMoneyFormatFor(String currencyCode) =>
    NumberFormat.compactSimpleCurrency(name: currencyCode);

final moneyFormatProvider = Provider<NumberFormat>((ref) {
  return moneyFormatFor(ref.watch(currencyCodeProvider));
});

final compactMoneyFormatProvider = Provider<NumberFormat>((ref) {
  return compactMoneyFormatFor(ref.watch(currencyCodeProvider));
});
