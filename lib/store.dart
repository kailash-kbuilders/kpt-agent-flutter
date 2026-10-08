import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class AppStore extends ChangeNotifier {
  SharedPreferences? _p;
  String providerId = 'openrouter';
  String projectPath = '';
  bool autoApply = true;
  String ollamaUrl = 'http://127.0.0.1:11434';
  final Map<String, String> _keys = {};
  final Map<String, String> _models = {};

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _p = p;
    providerId = p.getString('provider') ?? 'openrouter';
    projectPath = p.getString('projectPath') ?? '';
    autoApply = p.getBool('autoApply') ?? true;
    ollamaUrl = p.getString('ollamaUrl') ?? 'http://127.0.0.1:11434';
    for (final pr in LlmProvider.all) {
      _keys[pr.id] = p.getString('key_${pr.id}') ?? '';
      _models[pr.id] = p.getString('model_${pr.id}') ?? pr.defaultModel;
    }
    notifyListeners();
  }

  LlmProvider get provider => LlmProvider.byId(providerId);

  String keyFor(String id) => _keys[id] ?? '';

  String modelFor(String id) =>
      _models[id] ?? LlmProvider.byId(id).defaultModel;

  String get baseUrl => ollamaUrl;

  Future<void> saveProvider(
    String id, {
    required String key,
    required String model,
    required String url,
  }) async {
    providerId = id;
    _keys[id] = key.trim();
    _models[id] = model.trim().isEmpty
        ? LlmProvider.byId(id).defaultModel
        : model.trim();
    ollamaUrl = url.trim().isEmpty ? 'http://127.0.0.1:11434' : url.trim();
    final p = _p;
    if (p != null) {
      await p.setString('provider', providerId);
      await p.setString('key_$id', _keys[id] ?? '');
      await p.setString('model_$id', _models[id] ?? '');
      await p.setString('ollamaUrl', ollamaUrl);
    }
    notifyListeners();
  }

  Future<void> setProject(String path) async {
    projectPath = path;
    await _p?.setString('projectPath', path);
    notifyListeners();
  }

  Future<void> setAutoApply(bool v) async {
    autoApply = v;
    await _p?.setBool('autoApply', v);
    notifyListeners();
  }
}
