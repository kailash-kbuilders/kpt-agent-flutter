import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: {{CLASS}}()));
}

class {{CLASS}} extends StatelessWidget {
  const {{CLASS}}({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '{{TITLE}}',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: Scaffold(
        appBar: AppBar(title: const Text('{{TITLE}}')),
        body: const Center(
          child: Text('Project ready. KPT Agent se features add karo.'),
        ),
      ),
    );
  }
}
