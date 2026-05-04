import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LocalImageCacheService {
  static const _fileName = 'local_image_cache.json';
  static Map<String, String>? _memoryCache;

  static Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<Map<String, String>> _loadCache() async {
    if (_memoryCache != null) return _memoryCache!;
    try {
      final file = await _file;
      if (await file.exists()) {
        final contents = await file.readAsString();
        final Map<String, dynamic> json = jsonDecode(contents);
        _memoryCache = json.map((key, value) => MapEntry(key, value.toString()));
        return _memoryCache!;
      }
    } catch (_) {}
    _memoryCache = {};
    return _memoryCache!;
  }

  static Future<void> _saveCache(Map<String, String> cache) async {
    try {
      final file = await _file;
      await file.writeAsString(jsonEncode(cache));
      _memoryCache = cache;
    } catch (_) {}
  }

  static Future<void> saveImageMapping(String key, String imagePath) async {
    if (key.trim().isEmpty || imagePath.trim().isEmpty) return;
    final cache = await _loadCache();
    cache[key.trim().toLowerCase()] = imagePath;
    await _saveCache(cache);
  }

  static Future<String?> getImagePath(String key) async {
    if (key.trim().isEmpty) return null;
    final cache = await _loadCache();
    final path = cache[key.trim().toLowerCase()];
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        return path;
      }
    }
    return null;
  }
}
