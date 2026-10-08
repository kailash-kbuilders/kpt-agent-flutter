import 'package:flutter/material.dart';

import '../models.dart';
import '../services/llm_service.dart';
import '../store.dart';

class SettingsScreen extends StatefulWidget {
  final AppStore store;
  const SettingsScreen({super.key, required this.store});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _pid;
  final _key = TextEditingController();
  final _model = TextEditingController();
  final _url = TextEditingController();
  bool _hide = true;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _pid = widget.store.providerId;
    _url.text = widget.store.ollamaUrl;
    _loadFor(_pid);
  }

  void _loadFor(String id) {
    _key.text = widget.store.keyFor(id);
    _model.text = widget.store.modelFor(id);
  }

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    _url.dispose();
    super.dispose();
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _save() async {
    await widget.store.saveProvider(
      _pid,
      key: _key.text,
      model: _model.text,
      url: _url.text,
    );
    if (!mounted) return;
    _snack('Saved');
    Navigator.pop(context);
  }

  Future<void> _test() async {
    final pv = LlmProvider.byId(_pid);
    setState(() => _testing = true);
    try {
      final out = await LlmService.complete(
        provider: pv,
        apiKey: _key.text.trim(),
        model: _model.text.trim().isEmpty
            ? pv.defaultModel
            : _model.text.trim(),
        baseUrl: _url.text.trim(),
        system: 'Reply with the single word OK.',
        messages: const [
          {'role': 'user', 'content': 'ping'},
        ],
      );
      _snack('Connected: ${cut(out.trim(), 60)}');
    } catch (e) {
      _snack('Failed: ${cut('$e', 200)}');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pv = LlmProvider.byId(_pid);
    return Scaffold(
      appBar: AppBar(title: const Text('API Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Provider'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final o in LlmProvider.all)
                ChoiceChip(
                  label: Text(o.label),
                  selected: _pid == o.id,
                  onSelected: (_) {
                    setState(() {
                      _pid = o.id;
                      _loadFor(o.id);
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (pv.needsKey)
            TextField(
              controller: _key,
              obscureText: _hide,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'API key',
                hintText: pv.keyHint,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
            ),
          if (pv.needsKey) const SizedBox(height: 12),
          TextField(
            controller: _model,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Model',
              hintText: pv.defaultModel,
              border: const OutlineInputBorder(),
            ),
          ),
          if (pv.usesBaseUrl) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              autocorrect: false,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Ollama base URL',
                hintText: 'http://127.0.0.1:11434',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-apply agent actions'),
            subtitle: const Text('Off = pehle review, phir Apply button'),
            value: widget.store.autoApply,
            onChanged: (v) async {
              await widget.store.setAutoApply(v);
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testing ? null : _test,
                  icon: const Icon(Icons.wifi_tethering),
                  label: Text(_testing ? 'Testing...' : 'Test'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
