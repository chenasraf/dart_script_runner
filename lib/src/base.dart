import 'package:script_runner/src/config.dart';

/// Runs a script with the given name, and any extra arguments.
Future<void> runScript(String entryName, List<String> args) async {
  final config = await ScriptRunnerConfig.get();
  if (config.scripts.isEmpty) {
    throw StateError('No scripts found');
  }
  if (['-h', '--help'].contains(entryName)) {
    config.printUsage();
    return;
  }
  if (['-ls', '--list'].contains(entryName)) {
    final search = args.isNotEmpty ? args.first : '';
    config.printScripts(search);
    return;
  }
  final entry = config.scriptsMap[entryName];
  if (entry == null) {
    throw StateError(
      'No script named "$entryName" found.\n'
      'Available scripts: ${config.scriptsMap.keys.join(', ')}',
    );
  }

  return entry.run(args);
}
