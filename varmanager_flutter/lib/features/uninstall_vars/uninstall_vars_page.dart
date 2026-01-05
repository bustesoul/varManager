import 'package:flutter/material.dart';

class UninstallVarsPage extends StatelessWidget {
  const UninstallVarsPage({super.key, required this.payload});

  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final varList = (payload['var_list'] as List<dynamic>? ?? [])
        .map((item) => item.toString())
        .toList();
    final requested = (payload['requested'] as List<dynamic>? ?? [])
        .map((item) => item.toString())
        .toSet();
    final implicated = (payload['implicated'] as List<dynamic>? ?? [])
        .map((item) => item.toString())
        .toSet();

    return Scaffold(
      appBar: AppBar(title: const Text('Uninstall Preview')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Will uninstall ${varList.length} packages'),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                child: ListView.separated(
                  itemCount: varList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final name = varList[index];
                    final tags = <String>[];
                    if (requested.contains(name)) {
                      tags.add('Requested');
                    }
                    if (implicated.contains(name)) {
                      tags.add('Implicated');
                    }
                    return ListTile(
                      title: Text(name),
                      subtitle: tags.isEmpty ? null : Text(tags.join(' - ')),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
