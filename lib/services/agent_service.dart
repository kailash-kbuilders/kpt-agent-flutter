import 'dart:convert';

import '../models.dart';
import '../store.dart';
import 'llm_service.dart';
import 'project_service.dart';

class AgentService {
  static const String systemPrompt = r'''
You are "KPT Agent", an autonomous senior Flutter engineer operating directly on the local mobile file system.

RULES FOR FILE MANIPULATION:
1. You have full authority to create new files, write nested directories, and edit existing code inside the project folder.
2. All file paths are RELATIVE to the project root (e.g. lib/main.dart). Never use absolute paths or "..".
3. When you edit a file, return its COMPLETE new content (no "...", no placeholders).
4. Keep every file small and focused; split big features into several files so one reply never exceeds token limits.
5. Dependencies: use the EXECUTE_COMMAND action "flutter pub add <package>" (or edit pubspec.yaml). Do not run build commands.
6. The app is built later on GitHub Actions, so the code must compile with the stable Flutter SDK. Use only well-known packages.
7. Output ONLY one JSON object. No markdown fences, no text before or after it.

JSON Schema Response Format:
{
  "thought_process": "Architectural breakdown and strategy",
  "actions": [
    {
      "action_type": "CREATE_OR_UPDATE_FILE",
      "file_path": "lib/services/api_service.dart",
      "content": "DART_CODE_HERE"
    },
    {
      "action_type": "DELETE_FILE",
      "file_path": "lib/old_file.dart"
    },
    {
      "action_type": "EXECUTE_COMMAND",
      "command": "flutter pub add http"
    }
  ]
}
''';

  static Future<String> _context(ProjectService ps) async {
    final tree = await ps.listTree(maxEntries: 200);
    final sb = StringBuffer('FILE TREE:\n');
    if (tree.isEmpty) sb.writeln('(empty)');
    for (final e in tree) {
      sb.writeln(e.isDir ? '${e.rel}/' : e.rel);
    }
    for (final f in const ['pubspec.yaml', 'lib/main.dart']) {
      if (await ps.exists(f)) {
        try {
          final c = await ps.readFile(f);
          sb.writeln('\n--- $f ---');
          sb.writeln(cut(c, 4000));
        } catch (_) {}
      }
    }
    return sb.toString();
  }

  static Map<String, dynamic> extractJson(String raw) {
    var s = raw.trim();
    if (!s.startsWith('{')) {
      final m = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(s);
      if (m != null) s = (m.group(1) ?? '').trim();
    }
    final a = s.indexOf('{');
    final b = s.lastIndexOf('}');
    if (a < 0 || b <= a) throw const FormatException('No JSON object found');
    final decoded = jsonDecode(s.substring(a, b + 1));
    if (decoded is! Map) throw const FormatException('JSON is not an object');
    return Map<String, dynamic>.from(decoded);
  }

  static AgentPlan parse(String raw) {
    final j = extractJson(raw);
    final thought = (j['thought_process'] ?? j['thought'] ?? '').toString();
    final list = j['actions'];
    if (list is! List) throw const FormatException('"actions" list missing');
    final actions = <AgentAction>[];
    for (final a in list) {
      if (a is Map) {
        actions.add(AgentAction.fromJson(Map<String, dynamic>.from(a)));
      }
    }
    return AgentPlan(thought, actions);
  }

  static Future<AgentPlan> plan({
    required AppStore store,
    required ProjectService ps,
    required List<Map<String, String>> history,
    required String request,
    required void Function(String) onStatus,
  }) async {
    final pv = store.provider;
    final model = store.modelFor(pv.id);
    final ctx = await _context(ps);
    final msgs = <Map<String, String>>[
      ...history,
      {
        'role': 'user',
        'content': 'PROJECT CONTEXT:\n$ctx\n\nTASK:\n$request',
      },
    ];
    var lastErr = '';
    for (var attempt = 0; attempt < 2; attempt++) {
      onStatus(attempt == 0
          ? 'Calling ${pv.label} / $model ...'
          : 'Retrying (invalid JSON) ...');
      final raw = await LlmService.complete(
        provider: pv,
        apiKey: store.keyFor(pv.id),
        model: model,
        baseUrl: store.baseUrl,
        system: systemPrompt,
        messages: msgs,
      );
      try {
        final plan = parse(raw);
        onStatus('Plan ready: ${plan.actions.length} actions');
        return plan;
      } catch (e) {
        lastErr = '$e';
        msgs.add({'role': 'assistant', 'content': cut(raw, 2000)});
        msgs.add({
          'role': 'user',
          'content':
              'Your reply was not valid JSON ($lastErr). Reply again with ONLY the JSON object.',
        });
      }
    }
    throw LlmException('Model valid JSON nahi de paya: $lastErr');
  }

  static Future<int> apply({
    required AgentPlan plan,
    required ProjectService ps,
    required void Function(String) log,
  }) async {
    var ok = 0;
    for (final a in plan.actions) {
      try {
        switch (a.type) {
          case 'CREATE_OR_UPDATE_FILE':
            if (a.path == null || a.content == null) {
              throw Exception('file_path/content missing');
            }
            await ps.writeFile(a.path!, a.content!);
            log('[file] wrote ${a.path}');
            ok++;
            break;
          case 'DELETE_FILE':
            if (a.path == null) throw Exception('file_path missing');
            await ps.deleteFile(a.path!);
            log('[file] deleted ${a.path}');
            ok++;
            break;
          case 'EXECUTE_COMMAND':
            final cmd = a.command ?? '';
            log('\$ $cmd');
            final code = await ps.run(cmd, log);
            log('[exit $code]');
            if (code == 0) ok++;
            break;
          default:
            log('[skip] unknown action ${a.type}');
        }
      } catch (e) {
        log('[error] ${a.type}: $e');
      }
    }
    return ok;
  }
}
