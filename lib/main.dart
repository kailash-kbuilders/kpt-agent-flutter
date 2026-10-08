import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.load();
  runApp(KptApp(store: store));
}

class KptApp extends StatelessWidget {
  final AppStore store;
  const KptApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KPT Agent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF6C63FF),
      ),
      home: HomeScreen(store: store),
    );
  }
}
