import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';

class LlmException implements Exception {
  final String message;
  LlmException(this.message);
  @override
  String toString() => message;
}

String cut(String s, int n) => s.length <= n ? s : s.substring(0, n);

class LlmService {
  static const Duration _timeout = Duration(seconds: 240);

  static Future<String> complete({
    required LlmProvider provider,
    required String apiKey,
    required String model,
    required String baseUrl,
    required String system,
    required List<Map<String, String>> messages,
  }) {
    switch (provider.id) {
      case 'gemini':
        return _gemini(apiKey, model, system, messages);
      case 'ollama':
        return _ollama(baseUrl, model, system, messages);
      case 'groq':
        return _openAi(
          'https://api.groq.com/openai/v1/chat/completions',
          apiKey,
          model,
          system,
          messages,
          const {},
        );
      default:
        return _openAi(
          'https://openrouter.ai/api/v1/chat/completions',
          apiKey,
          model,
          system,
          messages,
          const {'HTTP-Referer': 'https://kpt-agent.app', 'X-Title': 'KPT Agent'},
        );
    }
  }

  static Future<Map<String, dynamic>> _post(
    Uri uri,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) async {
    try {
      final r = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json', ...headers},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      final text = utf8.decode(r.bodyBytes, allowMalformed: true);
      if (r.statusCode < 200 || r.statusCode >= 300) {
        throw LlmException('HTTP ${r.statusCode}: ${cut(text, 400)}');
      }
      return jsonDecode(text) as Map<String, dynamic>;
    } on LlmException {
      rethrow;
    } catch (e) {
      throw LlmException('Network/parse error: $e');
    }
  }

  static Future<String> _openAi(
    String url,
    String apiKey,
    String model,
    String system,
    List<Map<String, String>> messages,
    Map<String, String> extraHeaders,
  ) async {
    final j = await _post(
      Uri.parse(url),
      {'Authorization': 'Bearer $apiKey', ...extraHeaders},
      {
        'model': model,
        'messages': [
          {'role': 'system', 'content': system},
          ...messages,
        ],
      },
    );
    final choices = j['choices'];
    if (choices is! List || choices.isEmpty) {
      throw LlmException('Empty response: ${cut(jsonEncode(j), 300)}');
    }
    final msg = choices[0]['message'];
    final content = msg == null ? null : msg['content'];
    if (content == null) {
      throw LlmException('No content: ${cut(jsonEncode(j), 300)}');
    }
    return content.toString();
  }

  static Future<String> _ollama(
    String baseUrl,
    String model,
    String system,
    List<Map<String, String>> messages,
  ) async {
    var base = baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    final j = await _post(
      Uri.parse('$base/api/chat'),
      const {},
      {
        'model': model,
        'stream': false,
        'format': 'json',
        'messages': [
          {'role': 'system', 'content': system},
          ...messages,
        ],
      },
    );
    final msg = j['message'];
    final content = msg == null ? null : msg['content'];
    if (content == null) {
      throw LlmException('No content: ${cut(jsonEncode(j), 300)}');
    }
    return content.toString();
  }

  static Future<String> _gemini(
    String apiKey,
    String model,
    String system,
    List<Map<String, String>> messages,
  ) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );
    final contents = <Map<String, dynamic>>[];
    for (final m in messages) {
      contents.add({
        'role': m['role'] == 'assistant' ? 'model' : 'user',
        'parts': [
          {'text': m['content'] ?? ''},
        ],
      });
    }
    final j = await _post(
      uri,
      const {},
      {
        'systemInstruction': {
          'parts': [
            {'text': system},
          ],
        },
        'contents': contents,
        'generationConfig': {'responseMimeType': 'application/json'},
      },
    );
    final cands = j['candidates'];
    if (cands is! List || cands.isEmpty) {
      throw LlmException('Gemini empty response: ${cut(jsonEncode(j), 300)}');
    }
    final content = cands[0]['content'];
    final parts = content == null ? null : content['parts'];
    if (parts is! List) {
      throw LlmException('Gemini no parts: ${cut(jsonEncode(j), 300)}');
    }
    final sb = StringBuffer();
    for (final part in parts) {
      final t = part['text'];
      if (t != null) sb.write(t.toString());
    }
    return sb.toString();
  }
}
