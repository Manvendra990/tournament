DateTime apiDate(dynamic value, {DateTime? fallback}) {
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  if (value is Map) {
    final nested = value['date'] ?? value['value'] ?? value[r'$date'];
    if (nested != null) return apiDate(nested, fallback: fallback);
  }
  if (value != null) {
    final parsed = DateTime.tryParse(value.toString());
    if (parsed != null) return parsed.toLocal();
  }
  return fallback ?? DateTime.now();
}

String apiId(Map<String, dynamic> data) => (data['id'] ?? data['_id'] ?? '').toString();
