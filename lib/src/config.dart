library script_runner;

import 'dart:io' as io;
import 'package:script_runner/src/runnable_script.dart';
import 'package:yaml/yaml.dart' as yaml;
import 'package:path/path.dart' as path;
import 'package:file/file.dart';
import 'package:file/local.dart';

class ScriptRunnerConfig {
  final List<RunnableScript> scripts;
  final String? shell;
  final String? workingDir;
  final Map<String, String>? env;

  ScriptRunnerConfig({
    required this.scripts,
    this.shell,
    this.workingDir,
    this.env,
  });

  Map<String, RunnableScript> get scriptsMap => Map.fromIterable(
        scripts,
        key: (element) => (element as RunnableScript).name,
      );

  static Future<ScriptRunnerConfig> get([FileSystem? fileSystem]) async {
    final fs = fileSystem ?? LocalFileSystem();
    final source = (await _getPubspecScripts(fs)) ?? (await _getConfigScripts(fs));

    if (source == null) {
      throw StateError('Must provide scripts in either pubspec.yaml or script_runner.yaml');
    }

    final env = <String, String>{}..addAll(
        (source['env'] as yaml.YamlMap?)?.cast<String, String>() ?? {},
      );

    return ScriptRunnerConfig(
      shell: source['shell'],
      scripts: _parseScriptsList(source['scripts']),
      env: env,
      workingDir: source['cwd'],
    );
  }

  static Future<yaml.YamlMap?> _getPubspecScripts(FileSystem fileSystem) async {
    final filePath = path.join(fileSystem.currentDirectory.path, 'pubspec.yaml');
    final pubspec = await fileSystem.file(filePath).readAsString();
    final yaml.YamlMap contents = yaml.loadYaml(pubspec);
    final yaml.YamlMap? conf = contents['script_runner'];
    return conf;
  }

  static Future<yaml.YamlMap?>? _getConfigScripts(FileSystem fileSystem) async {
    final filePath = path.join(fileSystem.currentDirectory.path, 'script_runner.yaml');
    final pubspec = await fileSystem.file(filePath).readAsString();
    final yaml.YamlMap? conf = yaml.loadYaml(pubspec);
    return conf;
  }

  static List<RunnableScript> _parseScriptsList(yaml.YamlList scriptsRaw) {
    final scripts = scriptsRaw.map((script) => RunnableScript.fromYamlMap(script)).toList();
    return scripts.map((s) => s..dependencies = scripts).toList();
  }
}
