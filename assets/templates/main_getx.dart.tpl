import 'package:flutter/material.dart';
import 'package:get/get.dart';

void main() {
  runApp(const {{CLASS}}());
}

class {{CLASS}} extends StatelessWidget {
  const {{CLASS}}({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
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
