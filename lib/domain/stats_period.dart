enum StatsPeriod { day, week, month, year, all }

extension StatsPeriodLabel on StatsPeriod {
  String get label {
    return switch (this) {
      StatsPeriod.day => '日',
      StatsPeriod.week => '周',
      StatsPeriod.month => '月',
      StatsPeriod.year => '年',
      StatsPeriod.all => '全部',
    };
  }

  String distributionTitle() {
    return switch (this) {
      StatsPeriod.day => '今日分布',
      StatsPeriod.week => '本周分布',
      StatsPeriod.month => '本月分布',
      StatsPeriod.year => '本年分布',
      StatsPeriod.all => '全部累计',
    };
  }

  String totalRecordsLabel() {
    return switch (this) {
      StatsPeriod.day => '今日总记录',
      StatsPeriod.week => '本周总记录',
      StatsPeriod.month => '本月总记录',
      StatsPeriod.year => '本年总记录',
      StatsPeriod.all => '全部总记录',
    };
  }
}

extension StatsPeriodWindow on StatsPeriod {
  /// Returns the start and end (exclusive) of the natural period for [anchor].
  (DateTime start, DateTime end) windowFor(DateTime anchor) {
    final dayStart = DateTime(anchor.year, anchor.month, anchor.day);
    return switch (this) {
      StatsPeriod.day => (dayStart, dayStart.add(const Duration(days: 1))),
      StatsPeriod.week => (
          dayStart.subtract(Duration(days: anchor.weekday - 1)),
          dayStart
              .subtract(Duration(days: anchor.weekday - 1))
              .add(const Duration(days: 7)),
        ),
      StatsPeriod.month => (
          DateTime(anchor.year, anchor.month, 1),
          DateTime(anchor.year, anchor.month + 1, 1),
        ),
      StatsPeriod.year => (
          DateTime(anchor.year, 1, 1),
          DateTime(anchor.year + 1, 1, 1),
        ),
      StatsPeriod.all => (DateTime(0), DateTime(2100)),
    };
  }
}
