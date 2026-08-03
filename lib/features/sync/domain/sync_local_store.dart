import '../../habits/domain/habit.dart';
import '../../habits/domain/habit_occurrence.dart';
import '../../habits/domain/habit_quantity_log.dart';
import '../../money/domain/transaction.dart';
import '../../money/domain/wishlist_item.dart';
import '../data/shard_codec.dart';

/// App settings snapshot for the meta/settings shard.
class SyncSettingsSnapshot {
  const SyncSettingsSnapshot({
    required this.themeMode,
    required this.visualStyle,
    required this.currencyCode,
  });

  final String themeMode;
  final String visualStyle;
  final String currencyCode;
}

/// Full local dataset used to build / apply shards.
class SyncLocalSnapshot {
  const SyncLocalSnapshot({
    required this.habits,
    required this.occurrences,
    required this.quantityLogs,
    required this.transactions,
    required this.wishlist,
    required this.settings,
  });

  final List<Habit> habits;
  final List<HabitOccurrence> occurrences;
  final List<HabitQuantityLog> quantityLogs;
  final List<MoneyTransaction> transactions;
  final List<WishlistItem> wishlist;
  final SyncSettingsSnapshot settings;
}

/// Reads/writes local Drift (+ prefs) for sync without depending on UI.
abstract class SyncLocalStore {
  Future<SyncLocalSnapshot> loadSnapshot();

  /// Applies remote shards (already decoded). Meta shards replace fully;
  /// month shards replace that calendar month's rows.
  Future<void> applyShards(List<SyncShard> shards);

  Future<String> getOrCreateDeviceId();

  Future<DateTime?> getLastSyncedAt();

  Future<void> setLastSyncedAt(DateTime at);

  /// Last successfully synced local shard index (checksums + updatedAt).
  Future<String?> getLocalShardIndexJson();

  Future<void> setLocalShardIndexJson(String json);
}
