import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models.dart';
import '../services/agent_service.dart';
import '../services/project_service.dart';
import '../store.dart';
import 'editor_screen.dart';
import 'settings_screen.dart';

class AgentScreen extends StatefulWidget {
  final AppStore store;
  const AgentScreen({super.key, required this.store});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  late final ProjectService _ps;
  final _input = TextEditingController();
  final _cmd = TextEditingController();
  final _chatScroll = ScrollController();
  final _logScroll = ScrollController();
  final List<ChatMsg> _msgs = [];
  final List<String> _logs = [];
  final List<Map<String, String>> _history = [];
  List<TreeEntry> _tree = [];
  AgentPlan? _pending;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ps = ProjectService(widget.store.projectPath);
    _msgs.add(ChatMsg(
      'system',
      'Project: ${_ps.root}\n\nPRD ya feature prompt bhejo. '
          'Agent files banayega/edit karega.',
    ));
    _refresh();
  }

  @override
  void dispose() {
    _input.dispose();
    _cmd.dispose();
    _chatScroll.dispose();
    _logScroll.dispose();
    super.dispose();
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _refresh() async {
    try {
      final t = await _ps.listTree();
      if (mounted) setState(() => _tree = t);
    } catch (e) {
      _log('[error] tree: $e');
    }
  }

  void _log(String s) {
    if (!mounted) return;
    setState(() => _logs.add(s));
    _scrollDown(_logScroll);
  }

  void _scrollDown(ScrollController c) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (c.hasClients) {
        c.jumpTo(c.position.maxScrollExtent);
      }
    });
  }

  Future<void> _attachPrd() async {
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.any);
      if (r == null || r.files.isEmpty) return;
      final path = r.files.first.path;
      if (path == null) return;
      final txt = await File(path).readAsString();
      setState(() {
        _input.text = 'Build this app from the PRD below:\n\n$txt';
      });
    } catch (e) {
      _snack('File read nahi hui: $e');
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    final store = widget.store;
    final pv = store.provider;
    if (pv.needsKey && store.keyFor(pv.id).isEmpty) {
      _snack('Pehle Settings me API key daalo');
      return;
    }
    _input.clear();
    setState(() {
      _busy = true;
      _pending = null;
      _msgs.add(ChatMsg('user', text));
    });
    _scrollDown(_chatScroll);
    try {
      final plan = await AgentService.plan(
        store: store,
        ps: _ps,
        history: _history,
        request: text,
        onStatus: (s) => _log('[agent] $s'),
      );
      final files = plan.actions
          .where((a) => a.path != null)
          .map((a) => a.path!)
          .join(', ');
      _history.add({'role': 'user', 'content': text});
      _history.add({
        'role': 'assistant',
        'content': '${plan.thought}\nFiles: $files',
      });
      while (_history.length > 8) {
        _history.removeAt(0);
      }
      if (mounted) {
        setState(() => _msgs.add(ChatMsg('agent', plan.thought, plan: plan)));
        _scrollDown(_chatScroll);
      }
      if (store.autoApply) {
        await _apply(plan);
      } else if (mounted) {
        setState(() => _pending = plan);
      }
    } catch (e) {
      if (mounted) setState(() => _msgs.add(ChatMsg('error', '$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollDown(_chatScroll);
    }
  }

  Future<void> _apply(AgentPlan plan) async {
    _log('--- applying ${plan.actions.length} actions ---');
    final ok = await AgentService.apply(plan: plan, ps: _ps, log: _log);
    await _refresh();
    if (!mounted) return;
    setState(() {
      _pending = null;
      _msgs.add(ChatMsg(
        'system',
        'Done: $ok/${plan.actions.length} actions successful. '
            'Terminal tab me details dekho.',
      ));
    });
    _scrollDown(_chatScroll);
  }

  Future<void> _applyPending() async {
    final plan = _pending;
    if (plan == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _apply(plan);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runManual() async {
    final c = _cmd.text.trim();
    if (c.isEmpty) return;
    _cmd.clear();
    _log('\$ $c');
    final code = await _ps.run(c, _log);
    _log('[exit $code]');
    await _refresh();
  }

  (Color, Color) _colors(BuildContext context, String role) {
    final cs = Theme.of(context).colorScheme;
    switch (role) {
      case 'user':
        return (cs.primaryContainer, cs.onPrimaryContainer);
      case 'agent':
        return (cs.secondaryContainer, cs.onSecondaryContainer);
      case 'error':
        return (cs.errorContainer, cs.onErrorContainer);
      default:
        return (cs.tertiaryContainer, cs.onTertiaryContainer);
    }
  }

  Widget _bubble(BuildContext context, ChatMsg m) {
    final (bg, fg) = _colors(context, m.role);
    final plan = m.plan;
    return Align(
      alignment: m.role == 'user' ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.text.isNotEmpty)
              SelectableText(m.text, style: TextStyle(color: fg)),
            if (plan != null && plan.actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final a in plan.actions)
                Text(
                  a.summary,
                  style: TextStyle(
                    color: fg,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _agentTab() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _chatScroll,
            padding: const EdgeInsets.all(12),
            itemCount: _msgs.length + (_busy ? 1 : 0),
            itemBuilder: (context, i) {
              if (i >= _msgs.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                );
              }
              return _bubble(context, _msgs[i]);
            },
          ),
        ),
        if (_pending != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _applyPending,
                icon: const Icon(Icons.check),
                label: Text('Apply ${_pending!.actions.length} actions'),
              ),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Attach PRD file',
                  onPressed: _busy ? null : _attachPrd,
                  icon: const Icon(Icons.attach_file),
                ),
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'PRD ya feature prompt...',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: _busy ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _filesTab() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _tree.isEmpty ? 1 : _tree.length,
        itemBuilder: (context, i) {
          if (_tree.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Folder empty hai')),
            );
          }
          final e = _tree[i];
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.only(left: 12.0 + e.depth * 16.0),
            leading: Icon(
              e.isDir ? Icons.folder : Icons.insert_drive_file_outlined,
              size: 20,
            ),
            title: Text(p.basename(e.rel)),
            onTap: e.isDir
                ? null
                : () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditorScreen(ps: _ps, rel: e.rel),
                      ),
                    );
                    await _refresh();
                  },
          );
        },
      ),
    );
  }

  Color _logColor(String l) {
    if (l.startsWith('[error]') || l.startsWith('!') || l.startsWith('[blocked]')) {
      return Colors.redAccent;
    }
    if (l.startsWith('\$')) return Colors.amberAccent;
    if (l.startsWith('[file]') || l.startsWith('[pub]')) {
      return Colors.lightGreenAccent;
    }
    return Colors.white70;
  }

  Widget _terminalTab() {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            color: Colors.black,
            child: ListView.builder(
              controller: _logScroll,
              padding: const EdgeInsets.all(8),
              itemCount: _logs.length,
              itemBuilder: (context, i) => Text(
                _logs[i],
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: _logColor(_logs[i]),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cmd,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: const TextStyle(fontFamily: 'monospace'),
                    onSubmitted: (_) => _runManual(),
                    decoration: const InputDecoration(
                      prefixText: '\$ ',
                      hintText: 'flutter pub add http',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _runManual,
                  icon: const Icon(Icons.play_arrow),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(p.basename(_ps.root)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(store: widget.store),
                ),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.smart_toy_outlined), text: 'Agent'),
              Tab(icon: Icon(Icons.account_tree_outlined), text: 'Files'),
              Tab(icon: Icon(Icons.terminal), text: 'Terminal'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_agentTab(), _filesTab(), _terminalTab()],
        ),
      ),
    );
  }
}
