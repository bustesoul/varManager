import 'dart:io';

import 'package:path/path.dart' as path;

const String _buildVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '',
);

Future<String> loadAppVersion() async {
  if (_buildVersion.isNotEmpty) {
    return _buildVersion;
  }

  final candidates = <String>[
    path.join(File(Platform.resolvedExecutable).parent.path, 'VERSION'),
    path.join(Directory.current.path, 'VERSION'),
    path.join(Directory.current.parent.path, 'VERSION'),
  ];

  for (final candidate in candidates) {
    final file = File(candidate);
    if (await file.exists()) {
      final raw = await file.readAsString();
      final trimmed = raw.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
  }

  return 'unknown';
}
