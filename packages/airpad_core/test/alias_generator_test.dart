import 'dart:math';
import 'package:airpad_core/airpad_core.dart';
import 'package:test/test.dart';

void main() {
  group('AliasGenerator', () {
    test('generates two-word friendly names', () {
      final alias = AliasGenerator.generate();
      expect(alias, isNotEmpty);
      final parts = alias.split(' ');
      expect(parts.length, equals(2));
      expect(parts[0][0], equals(parts[0][0].toUpperCase()));
      expect(parts[1][0], equals(parts[1][0].toUpperCase()));
    });

    test('deterministic generation with fixed Random seed', () {
      final r1 = Random(42);
      final r2 = Random(42);
      final a1 = AliasGenerator.generate(r1);
      final a2 = AliasGenerator.generate(r2);
      expect(a1, equals(a2));
    });
  });
}
