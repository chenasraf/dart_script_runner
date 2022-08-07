library script_runner;

import 'package:script_runner/src/runnable_script.dart';
import 'package:yaml/yaml.dart' as yaml;
import 'package:path/path.dart' as path;
import 'package:file/file.dart';
import 'package:file/local.dart';

/// The configuration for a script runner. See each field's documentation for more information.
class ScriptRunnerConfig {
  /// The list of scripts in the config.
  final List<RunnableScript> scripts;

  /// The shell to use for running scripts. You may provide any executable path here.
  ///
  /// Shell will be run with the commands with `[shell] -c '...'`.
  final String? shell;

  /// The default working directory for the scripts to run in.
  /// If left `null`, defaults to current directory.
  final String? workingDir;

  /// Map of override environment variables for the scripts to run in.
  /// If left `null`, defaults to no overrides.
  final Map<String, String>? env;

  final FileSystem? _fileSystem;

  /// The filesystem used for loading scripts.
  FileSystem? get fileSystem => _fileSystem;

  /// Create a new script runner config from given arguments.
  /// Usually you would not want to call this, and instead load the config from a file using
  /// `ScriptRunnerConfig.get()`.
  ///
  /// See each argument for more details.
  ScriptRunnerConfig({
    required this.scripts,
    this.shell,
    this.workingDir,
    this.env,
    FileSystem? fileSystem,
  }) : _fileSystem = fileSystem ?? LocalFileSystem();

  /// A map of the registered scripts, keyed by name.
  Map<String, RunnableScript> get scriptsMap => Map.fromIterable(
        scripts,
        key: (element) => (element as RunnableScript).name,
      );

  /// Loads the script runner configuration from the current directory.
  /// You may give it a [FileSystem] to use, or it will use the default local one.
  ///
  /// The configuration is loaded in the following priority:
  ///
  /// 1. pubspec.yaml -> from 'script_runner' key
  /// 2. script_runner.yaml -> from '.' key (root)
  ///
  /// If none are found, an Exception is thrown.
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
      scripts: _parseScriptsList(source['scripts'], fileSystem: fs),
      env: env,
      workingDir: source['cwd'],
      fileSystem: fileSystem,
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

  static List<RunnableScript> _parseScriptsList(yaml.YamlList scriptsRaw,
      {FileSystem? fileSystem}) {
    final scripts = scriptsRaw
        .map((script) => RunnableScript.fromYamlMap(script, fileSystem: fileSystem))
        .toList();
    return scripts.map((s) => s..preloadScripts = scripts).toList();
  }

  void printUsage() {
    print('Dart Script Runner');
    print('  Usage: dartsc script_name ...args');
    print('');
    print('  ${'-h, --help'.padRight(16, ' ')} Print this help message');
    for (final scr in scripts) {
      print(
          '  ${scr.name.padRight(16, ' ')} ${scr.description ?? [scr.cmd, ...scr.args].join(' ')}');
    }
  }
}
