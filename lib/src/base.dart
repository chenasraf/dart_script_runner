import 'package:script_runner/src/config.dart';

/// Runs a script with the given name, and any extra arguments.
/// Returns the exit code.
Future<int> runScript(String entryName, List<String> args) async {
  final config = await ScriptRunnerConfig.get();
  if (config.scripts.isEmpty) {
    throw StateError('No scripts found');
  }
  if (['-h', '--help'].contains(entryName)) {
    config.printUsage();
    return 0;
  }
  if (['-ls', '--list'].contains(entryName)) {
    final search = args.isNotEmpty ? args.first : '';
    config.printScripts(search);
    return 0;
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
