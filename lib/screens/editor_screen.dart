import 'package:flutter/material.dart';

import '../services/project_service.dart';

/// TextEditingController that paints simple Dart-style syntax colors.
class CodeController extends TextEditingController {
  static const String _kw =
      'abstract|as|assert|async|await|break|case|catch|class|const|continue|'
      'default|do|else|enum|extends|factory|false|final|finally|for|get|if|'
      'implements|import|in|is|late|library|mixin|new|null|on|override|part|'
      'required|return|set|static|super|switch|this|throw|true|try|typedef|'
      'var|void|while|with|yield|int|double|String|bool|List|Map|Set|Future|'
      'Widget|BuildContext|dynamic';

  static final RegExp _re = RegExp(
    r'''(//[^\n]*)|("(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*')|\b(''' +
        _kw +
        r''')\b|\b(\d+(?:\.\d+)?)\b''',
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final src = text;
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in _re.allMatches(src)) {
      if (m.start > last) {
        spans.add(TextSpan(text: src.substring(last, m.start)));
      }
      Color color;
      var italic = false;
      if (m.group(1) != null) {
        color = const Color(0xFF7F8C98);
        italic = true;
      } else if (m.group(2) != null) {
        color = const Color(0xFFC3E88D);
      } else if (m.group(3) != null) {
        color = const Color(0xFFC792EA);
      } else {
        color = const Color(0xFFF78C6C);
      }
      spans.add(TextSpan(
        text: m.group(0),
        style: TextStyle(
          color: color,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        ),
      ));
      last = m.end;
    }
    if (last < src.length) spans.add(TextSpan(text: src.substring(last)));
    return TextSpan(style: style, children: spans);
  }
}

class EditorScreen extends StatefulWidget {
  final ProjectService ps;
  final String rel;
  const EditorScreen({super.key, required this.ps, required this.rel});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _c = CodeController();
  bool _loading = true;
  bool _dirty = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _c.text = await widget.ps.readFile(widget.rel);
    } catch (e) {
      _err = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    try {
      await widget.ps.writeFile(widget.rel, _c.text);
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rel, style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(
            icon: Icon(_dirty ? Icons.save : Icons.save_outlined),
            onPressed: _err == null ? _save : null,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_err != null
              ? Center(child: Text(_err!))
              : TextField(
                  controller: _c,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                  ),
                  onChanged: (_) {
                    if (!_dirty) setState(() => _dirty = true);
                  },
                )),
    );
  }
}
