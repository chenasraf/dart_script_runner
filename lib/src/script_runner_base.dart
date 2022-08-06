import 'dart:io';

import 'package:script_runner/src/utils.dart' as _utils;
import 'package:yaml/yaml.dart' as yaml;
import 'package:path/path.dart' as path;

Future<void> runScript(String entryName, List<String> args) async {
  final config = await getConfig();
  final entry = config.scriptsMap[entryName];
  if (entry == null) {
    throw Exception('No script named "$entryName" found.');
  }

  return entry.run(args);
}

Future<ScriptRunnerConfig> getConfig() async {
  final source = (await getPubspecScripts()) ?? (await getConfigScripts());

  if (source == null) {
    throw StateError('Must provide scripts in either pubspec.yaml or script_runner.yaml');
  }

  return ScriptRunnerConfig(source);
}

List<RunnableScript> parseScriptsList(yaml.YamlList scriptsRaw) {
  final scripts = scriptsRaw.map((script) => RunnableScript.fromMap(script)).toList();
  return scripts;
}

Future<List<RunnableScript>?> getPubspecScripts() async {
  final pubspec = await File(path.join(Directory.current.path, 'pubspec.yaml')).readAsString();
  final yaml.YamlMap contents = yaml.loadYaml(pubspec);
  final yaml.YamlMap? scriptsRaw = contents['script_runner'];
  if (scriptsRaw == null) {
    return null;
  }
  final scripts = parseScriptsList(scriptsRaw['scripts'] as yaml.YamlList);
  return scripts;
}

Future<List<RunnableScript>?>? getConfigScripts() async {
  final pubspec =
      await File(path.join(Directory.current.path, 'script_runner.yaml')).readAsString();
  final yaml.YamlList? contents = yaml.loadYaml(pubspec);
  if (contents == null) {
    return null;
  }
  final scripts = parseScriptsList(contents);
  return scripts;
}

class ScriptRunnerConfig {
  final List<RunnableScript> scripts;

  ScriptRunnerConfig(this.scripts);

  Map<String, RunnableScript> get scriptsMap {
    return Map.fromIterable(
      scripts,
      key: (element) => (element as RunnableScript).name,
    );
  }
}

class RunnableScript {
  final String name;
  final String cmd;
  final List<String> args;

  RunnableScript(this.name, {required this.cmd, required this.args});

  factory RunnableScript.fromMap(yaml.YamlMap map) {
    final cmdStr = map['cmd'] as String;
    final cmd = cmdStr.split(' ').first;
    final args = _utils.splitArgs(cmdStr.substring(cmd.length + 1));

    return RunnableScript(
      map['name'] as String,
      cmd: cmd,
      args: List<String>.from(args + (map['args'] ?? [])),
    );
  }

  Future<dynamic> run(List<String> extraArgs) async {
    final effectiveArgs = args + extraArgs;
    final argsStr = effectiveArgs.map((a) => a.contains(' ') ? '"$a"' : a).join(' ');
    print('Running: "$cmd" $argsStr');
    try {
      final result = await Process.run('/bin/sh', [
        '-c',
        [cmd, ...effectiveArgs].map((e) => '"$e"').join(' ')
      ]);
      stdout.write(result.stdout);
      stdout.write(result.stderr);
      final exitCode = result.exitCode;
      if (exitCode != 0) {
        // final stack = StackTrace.current;
        final e =
            ProcessException(cmd, args, 'Process exited with error code: $exitCode', exitCode);
        throw e;
      }
    } catch (e, stack) {
      rethrow;
    }
  }
}
