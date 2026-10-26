import 'package:flutter_test/flutter_test.dart';
import 'package:sabt_crm/core/utils/json_utils.dart';

void main() {
  group('json_utils helpers', () {
    test('asMap transforms dynamic map into Map<String, dynamic>', () {
      final dynamic raw = <dynamic, dynamic>{'key': 'value', 123: 'numeric_key'};
      final converted = asMap(raw);
      expect(converted, isNotNull);
      expect(converted?['key'], 'value');
      expect(converted?['123'], 'numeric_key');
      expect(asMap('string'), isNull);
      expect(asMap(null), isNull);
    });

    test('asDouble parses numeric types and comma-separated floats', () {
      expect(asDouble(42), 42.0);
      expect(asDouble(19.99), 19.99);
      expect(asDouble('12,50'), 12.5);
      expect(asDouble('100.25'), 100.25);
      expect(asDouble('invalid'), isNull);
      expect(asDouble(null), isNull);
      expect(asDoubleOr('invalid', 5.0), 5.0);
    });

    test('asInt parses integer, rounds float, and parses string integers', () {
      expect(asInt(42), 42);
      expect(asInt(14.8), 15);
      expect(asInt('120'), 120);
      expect(asInt('invalid'), isNull);
      expect(asInt(null), isNull);
      expect(asIntOr('invalid', 10), 10);
    });

    test('asBool correctly parses truthy and falsy values', () {
      expect(asBool(true), isTrue);
      expect(asBool(false), isFalse);
      expect(asBool(1), isTrue);
      expect(asBool(0), isFalse);
      expect(asBool('true'), isTrue);
      expect(asBool('True'), isTrue);
      expect(asBool('1'), isTrue);
      expect(asBool('yes'), isTrue);
      expect(asBool('false'), isFalse);
      expect(asBool('0'), isFalse);
      expect(asBool(null, fallback: true), isTrue);
      expect(asBool(null, fallback: false), isFalse);
    });

    test('asStringList handles diverse collections', () {
      expect(asStringList(['alpha', 123, true]), ['alpha', '123', 'true']);
      expect(asStringList(null), isEmpty);
      expect(asStringList('not a list'), isEmpty);
    });
  });
}
