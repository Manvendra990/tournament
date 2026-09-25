class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );

  static String absoluteUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://'))
      return value;
    final root = baseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
    return '$root${value.startsWith('/') ? value : '/$value'}';
  }
}
