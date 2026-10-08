import 'package:flutter/material.dart';

import '../models.dart';
import '../services/bootstrap_service.dart';
import '../services/project_service.dart';
import '../store.dart';
import 'agent_screen.dart';

class WizardScreen extends StatefulWidget {
  final AppStore store;
  const WizardScreen({super.key, required this.store});

  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen> {
  static const Set<String> _reserved = {
    'flutter', 'test', 'dart', 'assert', 'class', 'if', 'else', 'for',
    'while', 'new', 'null', 'true', 'false', 'var', 'void', 'this', 'super',
    'switch', 'case', 'default', 'return', 'try', 'catch', 'final', 'const',
    'enum', 'import', 'is', 'in', 'do', 'break', 'continue', 'throw', 'with',
    'abstract', 'as', 'async', 'await', 'dynamic', 'export', 'extends',
    'external', 'factory', 'get', 'implements', 'late', 'library', 'mixin',
    'on', 'operator', 'part', 'required', 'set', 'static', 'typedef', 'yield',
  };
  static const List<String> _allPlatforms = [
    'android', 'ios', 'web', 'windows', 'macos', 'linux',
  ];

  String? _folder;
  bool _empty = false;
  bool _writable = false;
  final _name = TextEditingController(text: 'my_app');
  final _org = TextEditingController(text: 'com.kailash');
  final Set<String> _platforms = {'android'};
  String _androidLang = 'kotlin';
  String _iosLang = 'swift';
  String _state = 'riverpod';
  String _layout = 'feature';
  bool _busy = false;
  final List<String> _log = [];

  @override
  void dispose() {
    _name.dispose();
    _org.dispose();
    super.dispose();
  }

  bool get _nameOk {
    final n = _name.text.trim();
    return RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(n) && !_reserved.contains(n);
  }

  bool get _orgOk => RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$')
      .hasMatch(_org.text.trim());

  bool get _canCreate =>
      _folder != null &&
      _empty &&
      _writable &&
      _nameOk &&
      _orgOk &&
      _platforms.isNotEmpty &&
      !_busy;

  Future<void> _check(String path) async {
    final empty = await ProjectService.isEmptyDir(path);
    final w = await ProjectService.canWrite(path);
    if (!mounted) return;
    setState(() {
      _folder = path;
      _empty = empty;
      _writable = w;
    });
  }

  Future<void> _pick() async {
    final path = await ProjectService.pickFolder();
    if (path != null) await _check(path);
  }

  Future<void> _useWorkspace() async {
    final n = _nameOk ? _name.text.trim() : 'my_app';
    final path = await ProjectService.defaultWorkspace(n);
    await _check(path);
  }

  Future<void> _create() async {
    final root = _folder;
    if (root == null) return;
    setState(() {
      _busy = true;
      _log.clear();
    });
    try {
      await BootstrapService.run(
        root: root,
        cfg: WizardConfig(
          name: _name.text.trim(),
          org: _org.text.trim(),
          platforms: _platforms,
          androidLang: _androidLang,
          iosLang: _iosLang,
          state: _state,
          layout: _layout,
        ),
        log: (s) {
          if (mounted) setState(() => _log.add(s));
        },
      );
      await widget.store.setProject(root);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AgentScreen(store: widget.store)),
      );
    } catch (e) {
      if (mounted) setState(() => _log.add('[error] $e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _choice(
      List<String> opts, String cur, void Function(String) onPick) {
    return Wrap(
      spacing: 8,
      children: [
        for (final o in opts)
          ChoiceChip(
            label: Text(o),
            selected: cur == o,
            onSelected: (_) => setState(() => onPick(o)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final folder = _folder;
    return Scaffold(
      appBar: AppBar(title: const Text('New Flutter Project')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('1. Folder', [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _pick,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Pick folder'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _useWorkspace,
                    icon: const Icon(Icons.phone_android),
                    label: const Text('App workspace'),
                  ),
                ),
              ],
            ),
            if (folder != null) ...[
              const SizedBox(height: 10),
              Text(folder, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Text(
                _empty ? 'OK: folder empty hai' : 'Folder empty nahi hai',
                style: TextStyle(
                    color: _empty ? Colors.greenAccent : Colors.redAccent),
              ),
              Text(
                _writable
                    ? 'OK: write access hai'
                    : 'Write access nahi. Settings > Apps > KPT Agent > '
                        'Permissions > All files access ON karo, ya '
                        '"App workspace" use karo.',
                style: TextStyle(
                    color: _writable ? Colors.greenAccent : Colors.redAccent),
              ),
            ],
          ]),
          _section('2. App details', [
            TextField(
              controller: _name,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'App name (dart identifier)',
                border: const OutlineInputBorder(),
                errorText: _nameOk ? null : 'a-z, 0-9, _ (letter se shuru)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _org,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Organization (com.company)',
                border: const OutlineInputBorder(),
                errorText: _orgOk ? null : 'Format: com.company',
              ),
            ),
          ]),
          _section('3. Platforms', [
            Wrap(
              spacing: 8,
              children: [
                for (final pl in _allPlatforms)
                  FilterChip(
                    label: Text(pl),
                    selected: _platforms.contains(pl),
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _platforms.add(pl);
                        } else {
                          _platforms.remove(pl);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Android language'),
            _choice(['kotlin', 'java'], _androidLang, (v) => _androidLang = v),
            const SizedBox(height: 8),
            const Text('iOS language'),
            _choice(['swift', 'objc'], _iosLang, (v) => _iosLang = v),
          ]),
          _section('4. Architecture', [
            const Text('State management'),
            _choice(['riverpod', 'bloc', 'provider', 'getx', 'none'], _state,
                (v) => _state = v),
            const SizedBox(height: 8),
            const Text('Folder layout'),
            _choice(['feature', 'clean'], _layout, (v) => _layout = v),
          ]),
          FilledButton.icon(
            onPressed: _canCreate ? _create : null,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.rocket_launch),
            label: Text(_busy ? 'Creating...' : 'Create project'),
          ),
          if (_log.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.black,
              child: Text(
                _log.join('\n'),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.greenAccent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
