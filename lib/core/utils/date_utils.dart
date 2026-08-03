DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime daysAgo(DateTime from, int days) => dateOnly(from).subtract(Duration(days: days));
