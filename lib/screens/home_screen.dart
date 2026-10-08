import 'dart:io';

import 'package:flutter/material.dart';

import '../services/project_service.dart';
import '../store.dart';
import 'agent_screen.dart';
import 'settings_screen.dart';
import 'wizard_screen.dart';

class HomeScreen extends StatelessWidget {
  final AppStore store;
  const HomeScreen({super.key, required this.store});

  void _go(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _openExisting(BuildContext context) async {
    final path = await ProjectService.pickFolder();
    if (path == null) return;
    final ok = await ProjectService.canWrite(path);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Folder me write access nahi. Settings > Apps > '
            'KPT Agent > Permissions > All files access ON karo.'),
      ));
      return;
    }
    await store.setProject(path);
    if (!context.mounted) return;
    _go(context, AgentScreen(store: store));
  }

  Widget _card(BuildContext context,
      {required IconData icon,
      required String title,
      required String sub,
      required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(sub),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final pv = store.provider;
        final keyOk = !pv.needsKey || store.keyFor(pv.id).isNotEmpty;
        final hasProject =
            store.projectPath.isNotEmpty && Directory(store.projectPath).existsSync();
        return Scaffold(
          appBar: AppBar(title: const Text('KPT Agent')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Autonomous Flutter developer workspace',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              _card(
                context,
                icon: Icons.key,
                title: '1. API Settings',
                sub: keyOk
                    ? '${pv.label} / ${store.modelFor(pv.id)}'
                    : 'API key set karo (${pv.label})',
                onTap: () => _go(context, SettingsScreen(store: store)),
              ),
              _card(
                context,
                icon: Icons.create_new_folder_outlined,
                title: '2. New Flutter Project',
                sub: 'Folder pick karo + setup wizard',
                onTap: () => _go(context, WizardScreen(store: store)),
              ),
              _card(
                context,
                icon: Icons.folder_open,
                title: '3. Open Existing Folder',
                sub: 'Kisi bhi Flutter folder par agent chalao',
                onTap: () => _openExisting(context),
              ),
              if (hasProject)
                _card(
                  context,
                  icon: Icons.play_circle_outline,
                  title: 'Continue last project',
                  sub: store.projectPath,
                  onTap: () => _go(context, AgentScreen(store: store)),
                ),
            ],
          ),
        );
      },
    );
  }
}
