import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DataClassName('HabitRow')
class Habits extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  TextColumn get kind => text().withDefault(const Constant('repeatable'))();
  TextColumn get scheduleJson => text().nullable()();
  /// JSON for [QuantityWindowGoal] when kind is quantity.
  TextColumn get goalJson => text().nullable()();
  IntColumn get reminderTimeMinutes => integer().nullable()();
  IntColumn get colorValue => integer().nullable()();
  TextColumn get iconName =>
      text().withDefault(const Constant('fitness_center'))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('HabitLogRow')
class HabitLogs extends Table {
  TextColumn get habitId =>
      text().references(Habits, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime()();
  BoolColumn get completed => boolean()();

  @override
  Set<Column> get primaryKey => {habitId, date};
}

@DataClassName('HabitOccurrenceRow')
class HabitOccurrences extends Table {
  TextColumn get id => text()();
  TextColumn get habitId =>
      text().references(Habits, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get dueAt => dateTime()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {habitId, dueAt},
      ];
}

@DataClassName('HabitQuantityLogRow')
class HabitQuantityLogs extends Table {
  TextColumn get id => text()();
  TextColumn get habitId =>
      text().references(Habits, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get loggedAt => dateTime()();
  RealColumn get quantity => real().withDefault(const Constant(1.0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TransactionRow')
class Transactions extends Table {
  TextColumn get id => text()();
  RealColumn get amount => real()();
  TextColumn get type => text()();
  TextColumn get category => text()();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get merchant => text().withDefault(const Constant(''))();
  TextColumn get externalId => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  DateTimeColumn get date => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {externalId},
      ];
}

@DataClassName('WishlistItemRow')
class WishlistItems extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  RealColumn get estimatedPrice => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get boughtAt => dateTime().nullable()();
  TextColumn get transactionId => text().nullable()();
  BoolColumn get isRecurring =>
      boolean().withDefault(const Constant(false))();
  IntColumn get recurrenceInterval => integer().nullable()();
  TextColumn get recurrenceUnit => text().nullable()();
  DateTimeColumn get nextDue => dateTime().nullable()();
  TextColumn get targetType =>
      text().withDefault(const Constant('expense'))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Habits,
    HabitLogs,
    HabitOccurrences,
    HabitQuantityLogs,
    Transactions,
    WishlistItems,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.addColumn(transactions, transactions.merchant);
            await m.addColumn(transactions, transactions.externalId);
            await m.addColumn(transactions, transactions.source);
            await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_external_id '
              'ON transactions (external_id) WHERE external_id IS NOT NULL',
            );
          }
          if (from < 3) {
            await m.addColumn(habits, habits.kind);
            await m.addColumn(habits, habits.scheduleJson);
            await m.addColumn(habits, habits.reminderTimeMinutes);
            await m.addColumn(habits, habits.colorValue);
            await m.addColumn(habits, habits.iconName);
            await m.createTable(habitOccurrences);

            await customStatement(
              "UPDATE habits SET kind = 'repeatable', "
              "schedule_json = '{\"interval\":1,\"unit\":\"day\"}' "
              "WHERE schedule_json IS NULL",
            );

            final logs = await select(habitLogs).get();
            var i = 0;
            for (final log in logs) {
              i++;
              await into(habitOccurrences).insert(
                HabitOccurrencesCompanion.insert(
                  id: 'migrated-${log.habitId}-$i',
                  habitId: log.habitId,
                  dueAt: log.date,
                  status: Value(log.completed ? 'completed' : 'missed'),
                  completedAt: Value(log.completed ? log.date : null),
                ),
                mode: InsertMode.insertOrIgnore,
              );
            }
          }
          if (from < 4) {
            await m.addColumn(habits, habits.goalJson);
            await m.createTable(habitQuantityLogs);
          }
          if (from < 5) {
            await m.createTable(wishlistItems);
          }
          if (from < 6) {
            await m.addColumn(wishlistItems, wishlistItems.isRecurring);
            await m.addColumn(wishlistItems, wishlistItems.recurrenceInterval);
            await m.addColumn(wishlistItems, wishlistItems.recurrenceUnit);
            await m.addColumn(wishlistItems, wishlistItems.nextDue);
            await m.addColumn(wishlistItems, wishlistItems.targetType);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'stat_maxxer');
  }
}
