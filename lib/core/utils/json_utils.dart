Map<String, dynamic>? asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return null;
}

List<dynamic> asList(dynamic value) => value is List ? value : const [];

String? asString(dynamic value) {
  if (value == null) return null;
  final text = '$value';
  return text.isEmpty ? null : text;
}

String asStringOr(dynamic value, String fallback) => asString(value) ?? fallback;

double? asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value'.replaceAll(',', '.'));
}

double asDoubleOr(dynamic value, double fallback) => asDouble(value) ?? fallback;

int? asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse('$value');
}

int asIntOr(dynamic value, int fallback) => asInt(value) ?? fallback;

bool asBool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = '$value'.toLowerCase();
  return text == 'true' || text == '1' || text == 'yes';
}

List<String> asStringList(dynamic value) {
  if (value is List) {
    return value.map((item) => '$item').where((item) => item.isNotEmpty).toList();
  }
  return const [];
}
