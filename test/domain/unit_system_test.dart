import 'package:flutter_test/flutter_test.dart';
import 'package:loggym/domain/unit_system.dart';

void main() {
  test('converts weights between kilograms and pounds', () {
    expect(UnitSystem.metric.weightFromKg(60), 60);
    expect(UnitSystem.imperial.weightFromKg(100), closeTo(220.46, 0.01));
    expect(UnitSystem.imperial.weightToKg(220.46), closeTo(100, 0.01));
  });

  test('converts distances between metres, kilometres and miles', () {
    expect(UnitSystem.metric.distanceFromMetres(5000), 5);
    expect(UnitSystem.imperial.distanceFromMetres(1609.344), 1);
    expect(UnitSystem.imperial.distanceToMetres(3.1), closeTo(4988.97, 0.01));
  });

  test('formats numbers without trailing zeros', () {
    expect(formatNumber(60), '60');
    expect(formatNumber(62.5), '62.5');
    expect(formatNumber(132.277), '132.3');
    expect(formatNumber(100), '100');
  });

  test('formats and parses durations', () {
    expect(formatDuration(90), '1:30');
    expect(formatDuration(3725), '1:02:05');
    expect(parseDuration('1:30'), 90);
    expect(parseDuration('1:02:05'), 3725);
    expect(parseDuration('45'), 45);
    expect(parseDuration('1:x'), isNull);
  });

  test('parses decimals with either separator', () {
    expect(parseDecimal('62,5'), 62.5);
    expect(parseDecimal('62.5'), 62.5);
    expect(parseDecimal(''), isNull);
  });
}
