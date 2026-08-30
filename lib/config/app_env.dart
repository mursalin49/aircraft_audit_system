import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppEnv {
  AppEnv._();

  static final Map<String, String> _fileValues = <String, String>{};
  static bool _loaded = false;
  static String _loadedAsset = '.env';

  static Future<void> load({String? assetName}) async {
    if (_loaded) {
      return;
    }

    final requestedAsset = const String.fromEnvironment('ENV_FILE').trim();
    final effectiveAsset = (assetName ?? requestedAsset).trim();
    _loadedAsset = effectiveAsset.isEmpty ? '.env' : effectiveAsset;

    try {
      final fileContents = await rootBundle.loadString(_loadedAsset);
      _fileValues
        ..clear()
        ..addAll(_parse(fileContents));
      debugPrint('Loaded environment values from $_loadedAsset');
    } on FlutterError {
      debugPrint(
        'Environment asset $_loadedAsset was not found. Runtime config will rely on --dart-define values and built-in defaults.',
      );
    } finally {
      _loaded = true;
    }
  }

  static String get apiBaseUrl => _definedValue(
    const String.fromEnvironment('API_BASE_URL'),
    'API_BASE_URL',
  );

  static String get cloudinaryCloudName => _definedValue(
    const String.fromEnvironment('CLOUDINARY_CLOUD_NAME'),
    'CLOUDINARY_CLOUD_NAME',
  );

  static String get cloudinaryUnsignedPreset => _definedValue(
    const String.fromEnvironment('CLOUDINARY_UNSIGNED_PRESET'),
    'CLOUDINARY_UNSIGNED_PRESET',
  );

  static String get cloudinaryApiKey => _fileValues['CLOUDINARY_API_KEY'] ?? '';

  static String get cloudinaryApiSecret =>
      _fileValues['CLOUDINARY_API_SECRET'] ?? '';

  static String get cloudinaryFolder => _fileValues['CLOUDINARY_FOLDER'] ?? '';

  static String get loadedAsset => _loadedAsset;

  static String _definedValue(String compileTimeValue, String key) {
    final normalizedCompileTimeValue = compileTimeValue.trim();
    if (normalizedCompileTimeValue.isNotEmpty) {
      return normalizedCompileTimeValue;
    }
    return (_fileValues[key] ?? '').trim();
  }

  static Map<String, String> _parse(String input) {
    final values = <String, String>{};

    for (final rawLine in input.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }

      final separatorIndex = line.indexOf('=');
      if (separatorIndex <= 0) {
        continue;
      }

      var key = line.substring(0, separatorIndex).trim();
      if (key.startsWith('export ')) {
        key = key.substring(7).trim();
      }

      var value = line.substring(separatorIndex + 1).trim();
      if (value.length >= 2) {
        final startsWithQuote = value.startsWith('"') || value.startsWith("'");
        final endsWithQuote = value.endsWith('"') || value.endsWith("'");
        if (startsWithQuote && endsWithQuote) {
          value = value.substring(1, value.length - 1);
        }
      }

      values[key] = value;
    }

    return values;
  }
}
