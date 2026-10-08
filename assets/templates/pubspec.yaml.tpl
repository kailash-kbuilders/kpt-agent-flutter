name: {{NAME}}
description: {{TITLE}} - created with KPT Agent.
publish_to: "none"
version: 1.0.0+1

environment:
  sdk: ">=3.0.0 <5.0.0"

dependencies:
  flutter:
    sdk: flutter
{{DEPS}}

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
