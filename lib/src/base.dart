import 'package:script_runner/src/config.dart';

Future<void> runScript(String entryName, List<String> args) async {
  final config = await ScriptRunnerConfig.get();
  final entry = config.scriptsMap[entryName];
  if (entry == null) {
    throw Exception(
      'No script named "$entryName" found.\n'
      'Available scripts: ${config.scriptsMap.keys.join(', ')}',
    );
  }

  return entry.run(args);
}
