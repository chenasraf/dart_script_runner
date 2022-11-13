library script_runner;

import 'dart:io';
import 'dart:math' as math;
import 'package:script_runner/src/runnable_script.dart';
import 'package:script_runner/src/utils.dart';
import 'package:yaml/yaml.dart';
// ignore: no_leading_underscores_for_library_prefixes
import 'utils.dart' as _utils;
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
  final ScriptRunnerShellConfig shell;

  /// The default working directory for the scripts to run in.
  /// If left `null`, defaults to current directory.
  final String? workingDir;

  /// Map of override environment variables for the scripts to run in.
  /// If left `null`, defaults to no overrides.
  final Map<String, String>? env;

  /// The length of the lines in the help description, which causes text overflowing to the next line when necessary.
  final int lineLength;

  final FileSystem? _fileSystem;

  /// The filesystem used for loading scripts.
  FileSystem? get fileSystem => _fileSystem;

  /// The source file path of the config. Might be null if the config was created from the constructor manually.
  String? configSource;

  /// Create a new script runner config from given arguments.
  /// Usually you would not want to call this, and instead load the config from a file using
  /// `ScriptRunnerConfig.get()`.
  ///
  /// See each argument for more details.
  ScriptRunnerConfig({
    required this.scripts,
    this.shell = const ScriptRunnerShellConfig(),
    this.workingDir,
    this.env,
    FileSystem? fileSystem,
    this.lineLength = 80,
    this.configSource,
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
    final startDir = fs.currentDirectory.path;

    final sourceMap = await _tryFindConfig(fs, startDir);

    if (sourceMap.isEmpty) {
      throw StateError(
          'Must provide scripts in either pubspec.yaml or script_runner.yaml');
    }

    final source = sourceMap.values.first;
    final configSource = sourceMap.keys.first;

    final env = <String, String>{}..addAll(
        (source['env'] as yaml.YamlMap?)?.cast<String, String>() ?? {},
      );

    return ScriptRunnerConfig(
      shell: ScriptRunnerShellConfig.parse(source['shell']),
      scripts: _parseScriptsList(source['scripts'], fileSystem: fs),
      env: env,
      workingDir: source['cwd'],
      fileSystem: fileSystem,
      lineLength: source['line_length'] ?? 80,
      configSource: configSource,
    );
  }

  static Future<yaml.YamlMap?> _getPubspecConfig(
      FileSystem fileSystem, String folderPath) async {
    final filePath = path.join(folderPath, 'pubspec.yaml');
    final file = fileSystem.file(filePath);
    if (!file.existsSync()) {
      return null;
    }
    final pubspec = await file.readAsString();
    final yaml.YamlMap contents = yaml.loadYaml(pubspec);
    try {
      final yaml.YamlMap? conf = contents['script_runner'];
      return conf;
    } catch (e) {
      throw StateError(
          'Expected YamlMap in pubspec.yaml under script_runner key, got: ${contents['script_runner'].runtimeType}');
    }
  }

  static Future<yaml.YamlMap?>? _getCustomConfig(
      FileSystem fileSystem, String folderPath) async {
    final filePath = path.join(folderPath, 'script_runner.yaml');
    final file = fileSystem.file(filePath);
    if (!file.existsSync()) {
      return null;
    }
    final pubspec = await file.readAsString();
    try {
      final yaml.YamlMap? conf = yaml.loadYaml(pubspec);
      return conf;
    } catch (e) {
      throw StateError(
          'Expected YamlMap in pubspec.yaml under script_runner key, got: ${yaml.loadYaml(pubspec).runtimeType}');
    }
  }

  static List<RunnableScript> _parseScriptsList(
    yaml.YamlList scriptsRaw, {
    FileSystem? fileSystem,
  }) {
    final scripts = scriptsRaw
        .map((script) =>
            RunnableScript.fromYamlMap(script, fileSystem: fileSystem))
        .toList();
    return scripts.map((s) => s..preloadScripts = scripts).toList();
  }

  /// Prints usage help text for this config
  void printUsage() {
    print('Dart Script Runner');
    print('  Usage: scr script_name ...args');
    print('');
    var maxLen = 0;
    for (final scr in scripts) {
      maxLen = math.max(maxLen, scr.name.length);
    }
    final padLen = maxLen + 6;
    print('  ${'-h, --help'.padRight(padLen, ' ')} Print this help message\n');
    print('');
    print(
      'Available scripts'
      '${configSource?.isNotEmpty == true ? ' on $configSource:' : ':'}',
    );
    print('');
    for (final scr in scripts) {
      final lines = _utils.chunks(
        scr.description ?? 'Run: ${[scr.cmd, ...scr.args].join(' ')}',
        80 - padLen,
      );
      print('  ${scr.name.padRight(padLen, ' ')} ${lines.first}');
      for (final line in lines.sublist(1)) {
        print('  ${''.padRight(padLen, ' ')} $line');
      }
      print('');
    }
  }

  static Future<Map<String, yaml.YamlMap>> _tryFindConfig(
      FileSystem fs, String startDir) async {
    var dir = fs.directory(startDir);
    String sourceFile;
    YamlMap? source;
    bool rootSearched = false;
    while (!rootSearched) {
      if (dir.parent.path == dir.path) {
        rootSearched = true;
      }
      source = await _getPubspecConfig(fs, dir.path);
      sourceFile = path.join(dir.path, 'pubspec.yaml');

      if (source == null) {
        source = await _getCustomConfig(fs, dir.path);
        sourceFile = path.join(dir.path, 'script_runner.yaml');
        if (source == null) {
          dir = dir.parent;
          continue;
        }
      }

      return {sourceFile: source};
    }

    return {};
  }
}

/// Configuration for shell to use for running scripts.
class ScriptRunnerShellConfig {
  final String? defaultShell;
  final String? windows;
  final String? macos;
  final String? linux;

  /// Create a new shell configuration from given arguments.
  /// When no shell is specified for a platform, the default shell is used.
  const ScriptRunnerShellConfig({
    this.defaultShell,
    this.windows,
    this.macos,
    this.linux,
  });

  /// Parses a shell configuration from a [YamlMap], [Map] or [String].
  /// Other types will throw a [StateError].
  factory ScriptRunnerShellConfig.parse(dynamic obj) {
    try {
      if (obj is String) {
        return ScriptRunnerShellConfig(defaultShell: obj);
      }
      if (obj is yaml.YamlMap || obj is Map) {
        return ScriptRunnerShellConfig(
          defaultShell: obj['default'],
          windows: obj['windows'],
          macos: obj['macos'],
          linux: obj['linux'],
        );
      }
      if (obj == null) {
        return ScriptRunnerShellConfig();
      }
      throw StateError('Invalid shell config: $obj');
    } catch (e) {
      throw StateError('Error while parsing config: $obj');
    }
  }

  /// Returns the shell for the current platform. If no overrides are specified in the config, it attempts to find
  /// the default shell for the platform.
  String get shell => _getShell();

  String _getShell() {
    if (Platform.isWindows) {
      return windows ?? defaultShell ?? _osShell();
    } else if (Platform.isMacOS) {
      return macos ?? defaultShell ?? _osShell();
    } else if (Platform.isLinux) {
      return linux ?? defaultShell ?? _osShell();
    }
    return defaultShell ?? _osShell();
  }

  String _osShell() {
    if (Platform.isWindows) {
      return 'cmd.exe';
    }
    try {
      final envShell = firstNonNull([
        Platform.environment['SHELL'],
        Platform.environment['TERM'],
      ]);
      return envShell ?? '/bin/sh';
    } catch (e) {
      return '/bin/sh';
    }
  }
}
