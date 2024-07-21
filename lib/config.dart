import 'dart:io';
import 'dart:math' as math;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:unaconfig/unaconfig.dart';

import 'runnable_script.dart';
import 'utils.dart';

/// The configuration for a script runner. See each field's documentation for more information.
class ScriptRunnerConfig {
  /// The list of scripts in the config.
  final List<RunnableScript> scripts;

  /// The shell to use for running scripts. You may provide any executable path here.
  ///
  /// Shell will be run with the commands with `[shell] -c '...'` (Linux/macOS) or `[shell] /K '...'` (Windows).
  final ScriptRunnerShellConfig shell;

  /// The default working directory for the scripts to run in.
  /// If left `null`, defaults to current directory.
  final String? workingDir;

  /// Map of optional override environment variables for the scripts to run in.
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
      throw ScriptStateError(
          'Must provide scripts in either pubspec.yaml or script_runner.yaml');
    }

    final source = sourceMap.values.first;
    final configSource = sourceMap.keys.first;

    final env = <String, String>{}..addAll(
        (source['env'] as Map?)?.cast<String, String>() ?? {},
      );

    return ScriptRunnerConfig(
      shell: ScriptRunnerShellConfig.parse(source['shell']),
      scripts: _parseScriptsList(source['scripts'], fileSystem: fs),
      env: env,
      workingDir: source['cwd'],
      fileSystem: fs,
      lineLength: source['line_length'] ?? 80,
      configSource: configSource,
    );
  }

  static List<RunnableScript> _parseScriptsList(
    List<dynamic>? scriptsRaw, {
    FileSystem? fileSystem,
  }) {
    final scripts = (scriptsRaw ?? [])
        .map((script) => RunnableScript.fromMap(script, fileSystem: fileSystem))
        .toList();
    return scripts.map((s) => s..preloadScripts = scripts).toList();
  }

  /// Prints usage help text for this config
  void printUsage() {
    print('');
    print(
      [
        colorize('Usage:', [TerminalColor.bold]),
        colorize('scr', [TerminalColor.yellow]),
        colorize('<script_name>', [TerminalColor.brightWhite]),
        colorize('[...args]', [TerminalColor.gray]),
      ].join(' '),
    );
    print(
      [
        ' ' * 'Usage:'.length,
        colorize('scr', [TerminalColor.yellow]),
        colorize('-h', [TerminalColor.brightWhite]),
      ].join(' '),
    );
    print('');
    final titleStyle = [TerminalColor.bold, TerminalColor.brightWhite];
    printColor('Built-in flags:', titleStyle);
    print('');
    printBuiltins();
    print('');

    print(
      [
        colorize('Available scripts', [
          TerminalColor.bold,
          TerminalColor.brightWhite,
        ]),
        (configSource?.isNotEmpty == true
            ? [
                colorize(' on ', titleStyle),
                colorize(
                    configSource!, [...titleStyle, TerminalColor.underline]),
                colorize(':', titleStyle)
              ].join('')
            : ':'),
      ].join(''),
    );
    print('');
    printScripts();
  }

  int _getPadLen(List<String> lines, [int? initial]) {
    var maxLen = initial ?? 0;
    for (final scr in scripts) {
      maxLen = math.max(maxLen, scr.name.length);
    }
    final padLen = maxLen + 6;
    return padLen;
  }

  /// Prints the list of scripts in the config.
  ///
  /// If [search] is provided, it filters the scripts to only those that contain the search string.
  void printScripts([String search = '']) {
    var maxLen = '-h, --help'.length;

    final filtered = search.isEmpty
        ? scripts
        : scripts
            .where((scr) => [scr.name, scr.description]
                .any((s) => s != null && s.contains(search)))
            .toList();

    final mapped = filtered
        .map((scr) => TableRow(scr.name,
            scr.description ?? '\$ ${[scr.cmd, ...scr.args].join(' ')}'))
        .toList();

    final padLen = _getPadLen(mapped.map((r) => r.name).toList(), maxLen);

    _printTable(mapped, padLen);
  }

  /// Prints the list of scripts in the config.
  ///
  /// If [search] is provided, it filters the scripts to only those that contain the search string.
  void printBuiltins([String search = '']) {
    final builtins = [
      TableRow('-ls, --list [search]',
          'List available scripts. Add search term to filter.'),
      TableRow('-h, --help', 'Print this help message'),
    ];

    final padLen = _getPadLen(builtins.map((b) => b.name).toList());

    _printTable(builtins, padLen);
  }

  void _printTable(List<TableRow> filtered, int padLen) {
    for (final scr in filtered) {
      final lines = chunks(
        scr.description,
        lineLength - padLen,
        stripColors: true,
        wrapLine: (line) => colorize(line, [TerminalColor.gray]),
      );
      printColor('  ${scr.name.padRight(padLen, ' ')} ${lines.first}',
          [TerminalColor.yellow]);
      for (final line in lines.sublist(1)) {
        print('  ${''.padRight(padLen, ' ')} $line');
      }
      print('');
    }
  }

  static Future<Map<String, Map>> _tryFindConfig(
      FileSystem fs, String startDir) async {
    final explorer = Unaconfig('script_runner', fs: fs);
    final config = await explorer.search();
    if (config != null) {
      final source = await explorer.findConfig();
      if (source != null) {
        return {source.path: config};
      }
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
  /// Other types will throw a [ScriptStateError].
  factory ScriptRunnerShellConfig.parse(dynamic obj) {
    try {
      if (obj is String) {
        return ScriptRunnerShellConfig(defaultShell: obj);
      }
      if (obj is Map || obj is Map) {
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
      throw ScriptStateError('Invalid shell config: $obj');
    } catch (e) {
      throw ScriptStateError('Error while parsing config: $obj');
    }
  }

  /// Returns the shell for the current platform. If no overrides are specified in the config, it attempts to find
  /// the default shell for the platform.
  String get shell => _getShell();

  /// Returns the shell command-line flag to indicate incoming command
  String get shellExecFlag => _getShellExecFlag();

  String _getShell() {
    switch (os) {
      case OS.windows:
        return windows ?? defaultShell ?? _osShell();
      case OS.macos:
        return macos ?? defaultShell ?? _osShell();
      case OS.linux:
        return linux ?? defaultShell ?? _osShell();
    }
  }

  String _getShellExecFlag() {
    switch (os) {
      case OS.windows:
        return '/K';
      case OS.macos:
      case OS.linux:
        return '-c';
    }
  }

  /// The current OS of the system, of those supported by [RunnableScript]
  OS get os {
    if (Platform.isWindows) {
      return OS.windows;
    } else if (Platform.isMacOS) {
      return OS.macos;
    } else if (Platform.isLinux) {
      return OS.linux;
    }
    throw ScriptStateError('Unsupported OS: ${Platform.operatingSystem}');
    // return OS.unknown;
  }

  String _osShell() {
    switch (os) {
      case OS.windows:
        return 'cmd.exe';
      case OS.linux:
      case OS.macos:
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
}

enum OS {
  windows,
  macos,
  linux,
  // other
}

class TableRow {
  final String name;
  final String description;

  TableRow(this.name, this.description);
}
