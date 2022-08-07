import 'dart:io';

// ignore: no_leading_underscores_for_library_prefixes
import 'package:script_runner/src/utils.dart' as _utils;
import 'package:yaml/yaml.dart' as yaml;
import 'package:path/path.dart' as path;

Future<void> runScript(String entryName, List<String> args) async {
  final config = await getConfig();
  final entry = config.scriptsMap[entryName];
  if (entry == null) {
    throw Exception(
        'No script named "$entryName" found. Available scripts: ${config.scriptsMap.keys.join(', ')}');
  }

  return entry.run(args);
}

Future<ScriptRunnerConfig> getConfig() async {
  final source = (await getPubspecScripts()) ?? (await getConfigScripts());

  if (source == null) {
    throw StateError('Must provide scripts in either pubspec.yaml or script_runner.yaml');
  }

  return ScriptRunnerConfig(
    shell: source['shell'],
    scripts: _parseScriptsList(source['scripts']),
  );
}

List<RunnableScript> _parseScriptsList(yaml.YamlList scriptsRaw) {
  final scripts = scriptsRaw.map((script) => RunnableScript.fromYamlMap(script)).toList();
  return scripts.map((s) => s..dependencies = scripts).toList();
}

Future<yaml.YamlMap?> getPubspecScripts() async {
  final pubspec = await File(path.join(Directory.current.path, 'pubspec.yaml')).readAsString();
  final yaml.YamlMap contents = yaml.loadYaml(pubspec);
  final yaml.YamlMap? conf = contents['script_runner'];
  return conf;
}

Future<yaml.YamlMap?>? getConfigScripts() async {
  final pubspec =
      await File(path.join(Directory.current.path, 'script_runner.yaml')).readAsString();
  final yaml.YamlMap? conf = yaml.loadYaml(pubspec);
  return conf;
}

class ScriptRunnerConfig {
  final List<RunnableScript> scripts;
  final String? shell;

  ScriptRunnerConfig({
    this.shell,
    required this.scripts,
  });

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
  List<RunnableScript> dependencies = [];

  RunnableScript(this.name, {required this.cmd, required this.args});

  factory RunnableScript.fromYamlMap(yaml.YamlMap map) {
    final out = <String, dynamic>{};

    if (map['name'] == null && map.keys.length == 1) {
      out['name'] = map.keys.first;
      out['cmd'] = map.values.first;
    } else {
      out.addAll(map.cast<String, dynamic>());
      out['args'] = (map['args'] as yaml.YamlList?)?.map((e) => e.toString()).toList();
    }

    return RunnableScript.fromMap(out);
  }

  factory RunnableScript.fromMap(Map<String, dynamic> map) {
    final name = map['name'] as String;
    final rawCmd = map['cmd'] as String;
    final cmd = rawCmd.split(' ').first;
    final rawArgs = (map['args'] as List<String>?) ?? [];
    final cmdArgs = _utils.splitArgs(rawCmd.substring(cmd.length));
    // print('cmdArgs: $cmdArgs');

    return RunnableScript(
      name,
      cmd: cmd,
      args: cmdArgs + List<String>.from(rawArgs),
    );
  }

  Future<dynamic> run(List<String> extraArgs) async {
    final effectiveArgs = args + extraArgs;
    // final argsStr = effectiveArgs.map(_wrap).join(' ');
    final shell = (await getConfig()).shell ?? '/bin/sh';

    final preRun = dependencies.map((d) => 'alias ${d.name}=\'dartsc ${d.name}\'').join(';');
    final origCmd = [cmd, ...effectiveArgs.map(_wrap)].join(' ');
    final passCmd = '$preRun; eval \'$origCmd\'';

    print('Running: $origCmd');
    // print("Before parse $cmd $args");

    try {
      final result = await Process.start(shell, [
        '-c',
        passCmd,
      ]);
      result.stdout.listen((event) {
        stdout.write(String.fromCharCodes(event));
      });
      result.stderr.listen((event) {
        stdout.write(String.fromCharCodes(event));
      });
      final exitCode = await result.exitCode;
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

String _wrap(String arg) {
  if (arg.contains(' ')) {
    return '"$arg"';
  }
  return arg;
}
