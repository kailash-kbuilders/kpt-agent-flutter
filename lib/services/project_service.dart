import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models.dart';

class ProjectException implements Exception {
  final String message;
  ProjectException(this.message);
  @override
  String toString() => message;
}

/// All file operations are sandboxed to [root].
class ProjectService {
  final String root;
  ProjectService(String path) : root = p.normalize(path);

  static const Set<String> _ignored = {
    '.git',
    '.dart_tool',
    'build',
    '.gradle',
    '.idea',
    'node_modules',
  };

  // ---------- static helpers (folder picking / checks) ----------

  static Future<String?> pickFolder() => FilePicker.platform.getDirectoryPath();

  static Future<String> defaultWorkspace(String projectName) async {
    Directory? base;
    try {
      base = await getExternalStorageDirectory();
    } catch (_) {
      base = null;
    }
    base ??= await getApplicationDocumentsDirectory();
    return p.join(base.path, 'kpt_projects', projectName);
  }

  static Future<bool> isEmptyDir(String path) async {
    final d = Directory(path);
    if (!await d.exists()) return true;
    return await d.list().isEmpty;
  }

  static Future<bool> canWrite(String path) async {
    try {
      final d = Directory(path);
      if (!await d.exists()) await d.create(recursive: true);
      final f = File(p.join(path, '.kpt_write_test'));
      await f.writeAsString('ok');
      await f.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------- sandboxed file ops ----------

  String resolve(String rel) {
    var r = rel.trim().replaceAll('\\', '/');
    while (r.startsWith('/')) {
      r = r.substring(1);
    }
    if (r.isEmpty) throw ProjectException('Empty file path');
    final full = p.normalize(p.join(root, r));
    if (!p.isWithin(root, full)) {
      throw ProjectException('Path outside project blocked: $rel');
    }
    return full;
  }

  Future<String> readFile(String rel) async {
    final f = File(resolve(rel));
    if (!await f.exists()) throw ProjectException('File not found: $rel');
    try {
      return await f.readAsString();
    } catch (_) {
      throw ProjectException('Not a text file: $rel');
    }
  }

  Future<void> writeFile(String rel, String content) async {
    final f = File(resolve(rel));
    await f.parent.create(recursive: true);
    await f.writeAsString(content);
  }

  Future<void> deleteFile(String rel) async {
    final full = resolve(rel);
    final t = await FileSystemEntity.type(full);
    if (t == FileSystemEntityType.directory) {
      await Directory(full).delete(recursive: true);
    } else if (t == FileSystemEntityType.file) {
      await File(full).delete();
    } else {
      throw ProjectException('Nothing to delete: $rel');
    }
  }

  Future<bool> exists(String rel) async {
    try {
      return await File(resolve(rel)).exists();
    } catch (_) {
      return false;
    }
  }

  Future<List<TreeEntry>> listTree({int maxEntries = 400}) async {
    final out = <TreeEntry>[];

    Future<void> walk(Directory d, int depth) async {
      if (out.length >= maxEntries) return;
      final items = await d.list(followLinks: false).toList();
      items.sort((a, b) {
        final ad = a is Directory;
        final bd = b is Directory;
        if (ad != bd) return ad ? -1 : 1;
        return p
            .basename(a.path)
            .toLowerCase()
            .compareTo(p.basename(b.path).toLowerCase());
      });
      for (final e in items) {
        if (out.length >= maxEntries) return;
        final name = p.basename(e.path);
        if (_ignored.contains(name)) continue;
        final isDir = e is Directory;
        out.add(TreeEntry(p.relative(e.path, from: root), isDir, depth));
        if (isDir) await walk(e, depth + 1);
      }
    }

    final r = Directory(root);
    if (await r.exists()) await walk(r, 0);
    return out;
  }

  // ---------- command execution ----------

  static String? guard(String cmd) {
    if (cmd.isEmpty) return 'empty command';
    if (cmd.length > 2000) return 'command too long';
    final rules = <RegExp, String>{
      RegExp(r'\bsudo\b'): 'sudo not allowed',
      RegExp(r'(^|[\s;&|])\.\.(/|\s|$)'): 'parent directory (..) not allowed',
      RegExp(r'(^|[\s;&|<>=])/(?!dev/null)\w'):
          'absolute paths outside project not allowed',
      RegExp(r'~|\$HOME'): 'home directory not allowed',
      RegExp(r'\b(mkfs|shutdown|reboot)\b'): 'dangerous command',
    };
    for (final e in rules.entries) {
      if (e.key.hasMatch(cmd)) return e.value;
    }
    return null;
  }

  static Future<bool> _hasTool(String name) async {
    try {
      final r = await Process.run('sh', ['-c', 'command -v $name']);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<int> run(String command, void Function(String) log) async {
    final cmd = command.trim();
    final bad = guard(cmd);
    if (bad != null) {
      log('[blocked] $bad');
      return 126;
    }

    final add = RegExp(r'^(?:flutter|dart)\s+pub\s+add\s+(.+)$').firstMatch(cmd);
    if (add != null) {
      return _emulatePubAdd(add.group(1) ?? '', log);
    }

    final hasFlutter = await _hasTool('flutter');
    if (!hasFlutter &&
        RegExp(r'^(?:flutter|dart)\s+pub\s+get\b').hasMatch(cmd)) {
      log('[info] flutter is device par installed nahi hai - '
          'pub get GitHub Actions build me chalega.');
      return 0;
    }

    try {
      final proc = await Process.start(
        'sh',
        ['-c', cmd],
        workingDirectory: root,
      );
      final dec = const Utf8Decoder(allowMalformed: true);
      final out = proc.stdout
          .transform(dec)
          .transform(const LineSplitter())
          .forEach(log);
      final err = proc.stderr
          .transform(dec)
          .transform(const LineSplitter())
          .forEach((l) => log('! $l'));
      await Future.wait([out, err]);
      final code = await proc.exitCode;
      if (code == 127) {
        log('[hint] command not found. Android par sirf basic shell commands '
            'chalte hain; build GitHub Actions par hoga.');
      }
      return code;
    } catch (e) {
      log('[error] $e');
      return 1;
    }
  }

  /// Offline replacement for `flutter pub add` - edits pubspec.yaml directly.
  Future<int> _emulatePubAdd(String args, void Function(String) log) async {
    final f = File(p.join(root, 'pubspec.yaml'));
    if (!await f.exists()) {
      log('[error] pubspec.yaml not found');
      return 1;
    }
    final lines = (await f.readAsString()).split('\n');
    var dev = false;
    final pkgs = <String>[];
    for (final raw in args.split(RegExp(r'\s+'))) {
      var t = raw.trim();
      if (t.isEmpty) continue;
      if (t == '--dev' || t == '-d') {
        dev = true;
        continue;
      }
      if (t.startsWith('-')) continue;
      if (t.startsWith('dev:')) {
        dev = true;
        t = t.substring(4);
      }
      pkgs.add(t);
    }
    if (pkgs.isEmpty) {
      log('[error] no package given');
      return 1;
    }
    final section = dev ? 'dev_dependencies:' : 'dependencies:';
    var code = 0;
    for (final t in pkgs) {
      var name = t;
      var ver = 'any';
      final i = t.indexOf(':');
      if (i > 0) {
        name = t.substring(0, i);
        ver = t.substring(i + 1);
        if (ver.isEmpty) ver = 'any';
      }
      if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
        log('[error] invalid package name: $name');
        code = 1;
        continue;
      }
      if (ver.contains(' ') || ver.contains('<') || ver.contains('>')) {
        ver = '"$ver"';
      }
      final exists = RegExp('^  ${RegExp.escape(name)}:');
      if (lines.any((l) => exists.hasMatch(l))) {
        log('[pub] $name already in pubspec.yaml');
        continue;
      }
      var idx = lines.indexWhere((l) => l.trimRight() == section);
      if (idx < 0) {
        lines.add('');
        lines.add(section);
        idx = lines.length - 1;
      }
      lines.insert(idx + 1, '  $name: $ver');
      log('[pub] added $name: $ver');
    }
    await f.writeAsString(lines.join('\n'));
    return code;
  }
}
