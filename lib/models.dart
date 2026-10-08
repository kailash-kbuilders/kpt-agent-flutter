class LlmProvider {
  final String id;
  final String label;
  final String defaultModel;
  final String keyHint;
  final bool needsKey;
  final bool usesBaseUrl;

  const LlmProvider({
    required this.id,
    required this.label,
    required this.defaultModel,
    required this.keyHint,
    this.needsKey = true,
    this.usesBaseUrl = false,
  });

  static const List<LlmProvider> all = [
    LlmProvider(
      id: 'openrouter',
      label: 'OpenRouter',
      defaultModel: 'openai/gpt-4o-mini',
      keyHint: 'sk-or-...',
    ),
    LlmProvider(
      id: 'groq',
      label: 'Groq',
      defaultModel: 'llama-3.3-70b-versatile',
      keyHint: 'gsk_...',
    ),
    LlmProvider(
      id: 'gemini',
      label: 'Gemini',
      defaultModel: 'gemini-2.5-flash',
      keyHint: 'AIza...',
    ),
    LlmProvider(
      id: 'ollama',
      label: 'Ollama',
      defaultModel: 'qwen2.5-coder:7b',
      keyHint: '(key not needed)',
      needsKey: false,
      usesBaseUrl: true,
    ),
  ];

  static LlmProvider byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return all.first;
  }
}

class AgentAction {
  final String type;
  final String? path;
  final String? content;
  final String? command;

  const AgentAction({
    required this.type,
    this.path,
    this.content,
    this.command,
  });

  factory AgentAction.fromJson(Map<String, dynamic> j) {
    var t = (j['action_type'] ?? j['type'] ?? '').toString().toUpperCase();
    if (t == 'CREATE_FILE' || t == 'UPDATE_FILE') {
      t = 'CREATE_OR_UPDATE_FILE';
    }
    if (t == 'EXECUTE_CLI') t = 'EXECUTE_COMMAND';
    final p = j['file_path'] ?? j['path'];
    final c = j['content'];
    final cmd = j['command'];
    return AgentAction(
      type: t,
      path: p?.toString(),
      content: c?.toString(),
      command: cmd?.toString(),
    );
  }

  String get summary {
    switch (type) {
      case 'CREATE_OR_UPDATE_FILE':
        return '+ ${path ?? '?'}';
      case 'DELETE_FILE':
        return '- ${path ?? '?'}';
      case 'EXECUTE_COMMAND':
        return '\$ ${command ?? '?'}';
      default:
        return '? $type';
    }
  }
}

class AgentPlan {
  final String thought;
  final List<AgentAction> actions;
  const AgentPlan(this.thought, this.actions);
}

class ChatMsg {
  final String role; // user | agent | system | error
  final String text;
  final AgentPlan? plan;
  const ChatMsg(this.role, this.text, {this.plan});
}

class TreeEntry {
  final String rel;
  final bool isDir;
  final int depth;
  const TreeEntry(this.rel, this.isDir, this.depth);
}

class WizardConfig {
  final String name;
  final String org;
  final Set<String> platforms;
  final String androidLang;
  final String iosLang;
  final String state;
  final String layout;

  const WizardConfig({
    required this.name,
    required this.org,
    required this.platforms,
    required this.androidLang,
    required this.iosLang,
    required this.state,
    required this.layout,
  });
}
