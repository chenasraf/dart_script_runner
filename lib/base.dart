import 'config.dart';
import 'utils.dart';

/// Runs a script with the given name, and any extra arguments.
/// Returns the exit code.
Future<int> runScript(String entryName, List<String> args) async {
  final config = await ScriptRunnerConfig.get();

  if (config.scripts.isEmpty) {
    throw ScriptStateError('No scripts found');
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
    final suggestions =
        config.scriptsMap.keys.where((key) => key.toLowerCase().startsWith(entryName.toLowerCase())).toList();

    if (suggestions.isNotEmpty) {
      if (suggestions.length == 1) {
        throw ScriptStateError(
          'No script named "$entryName" found. Did you mean "${suggestions.single}"?',
        );
      } else {
        throw ScriptStateError(
          'No script named "$entryName" found.\n'
          'Did you mean one of: "${suggestions.join('", "')}"?',
        );
      }
    } else {
      throw ScriptStateError(
        'No script named "$entryName" found.\n'
        'Available scripts: ${config.scriptsMap.keys.join('", "')}',
      );
    }
  }

  return entry.run(args);
}
