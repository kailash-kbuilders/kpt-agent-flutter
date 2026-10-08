# KPT Agent

Autonomous AI Flutter developer workspace (Android). Flutter, Material 3.

Phase 1: folder pick + setup wizard -> Flutter project skeleton (offline `flutter create` equivalent)
Phase 2: AI agent PRD/prompt se files create/edit/delete + commands chalata hai.

Providers: OpenRouter, Groq, Gemini, Ollama.

## Termux se push

    git init
    git add .
    git commit -m "KPT Agent v1.2.0"
    git branch -M main
    git remote add origin https://github.com/kailash-kbuilders/kpt-agent-flutter.git
    git push -u origin main --force

GitHub > Actions > Build APK > Artifacts (kpt-agent-apk) se APK download karo.
