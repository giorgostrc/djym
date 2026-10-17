enum UnitSystem { metric, imperial }

const _poundsPerKilogram = 2.2046226218;
const _metresPerMile = 1609.344;

extension UnitConversion on UnitSystem {
  String get weightUnit => switch (this) {
    UnitSystem.metric => 'kg',
    UnitSystem.imperial => 'lb',
  };

  String get distanceUnit => switch (this) {
    UnitSystem.metric => 'km',
    UnitSystem.imperial => 'mi',
  };

  double weightFromKg(double kg) => switch (this) {
    UnitSystem.metric => kg,
    UnitSystem.imperial => kg * _poundsPerKilogram,
  };

  double weightToKg(double weight) => switch (this) {
    UnitSystem.metric => weight,
    UnitSystem.imperial => weight / _poundsPerKilogram,
  };

  double distanceFromMetres(double metres) => switch (this) {
    UnitSystem.metric => metres / 1000,
    UnitSystem.imperial => metres / _metresPerMile,
  };

  double distanceToMetres(double distance) => switch (this) {
    UnitSystem.metric => distance * 1000,
    UnitSystem.imperial => distance * _metresPerMile,
  };
}

/// Formats a number with at most [decimals] decimals and no trailing zeros.
String formatNumber(double value, {int decimals = 1}) {
  final fixed = value.toStringAsFixed(decimals);
  return fixed.contains('.')
      ? fixed.replaceFirst(RegExp(r'\.?0+$'), '')
      : fixed;
}

/// `90` → `1:30`, `3725` → `1:02:05`.
String formatDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$rest'
      : '$minutes:$rest';
}

/// Reads `m:ss`, `h:mm:ss` or plain seconds; returns null when unreadable.
int? parseDuration(String text) {
  final parts = text.trim().split(':');
  if (parts.length > 3) return null;
  final numbers = parts.map(int.tryParse).toList();
  if (numbers.contains(null)) return null;
  return numbers.fold<int>(0, (total, part) => total * 60 + part!);
}

/// Accepts both `.` and `,` as the decimal separator.
double? parseDecimal(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));
