import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:script_runner/src/config.dart';
// ignore: no_leading_underscores_for_library_prefixes
import 'package:script_runner/src/utils.dart' as _utils;

/// A runnable script with pre-defined name, cmd and args. May be run using the `run` command and optionally
/// supplying extra arguments to pass.
class RunnableScript {
  /// The name of the script, as defined in the config.
  final String name;

  /// The description of the script, used in help messages.
  final String? description;

  /// The command to run the script with.
  final String cmd;

  /// The arguments to pass to the script.
  final List<String> args;

  /// The working directory to run the script in.
  ///
  /// If not provided, defaults to the working directory in the config.
  ///
  /// If that is also null, defaults to the current directory.
  final String? workingDir;

  /// The environment variables to run the script in.
  /// This map is appended to the one given in the config.
  final Map<String, String>? env;

  /// Other scripts in the config which are runnable by this script.
  /// The script loader pre-loads these as temporary aliases to allow combined scripts to be run.
  List<RunnableScript> preloadScripts = [];

  /// When set to `false`, the command will not print "$ ..." before running the command.
  /// This is useful for using the output in other scripts.
  ///
  /// Defaults to `true`.
  final bool displayCmd;

  /// When set to `true`, the command will end with a newline. This is useful for using the output in other scripts.
  ///
  /// Defaults to `false`.
  final bool appendNewline;

  FileSystem _fileSystem;

  /// A runnable script with pre-defined name, cmd and args. May be run using the `run` command and optionally
  /// supplying extra arguments to pass.
  RunnableScript(
    this.name, {
    required this.cmd,
    required this.args,
    this.description,
    this.workingDir,
    this.env,
    FileSystem? fileSystem,
    this.displayCmd = false,
    this.appendNewline = false,
  }) : _fileSystem = fileSystem ?? LocalFileSystem();

  /// Generate a runnable script from a normal map as defined in the config.
  factory RunnableScript.fromMap(
    Map<String, dynamic> map, {
    FileSystem? fileSystem,
  }) {
    if (map['name'] == null && map.keys.length == 1) {
      map['name'] = map.keys.first;
      map['cmd'] = map.values.first;
    } else {
      map.addAll(map.cast<String, dynamic>());
      map['args'] = (map['args'] as List?)?.map((e) => e.toString()).toList();
      map['env'] = (map['env'] as Map?)?.cast<String, String>();
    }
    final name = map['name'] as String;
    final rawCmd = map['cmd'] as String;
    final cmd = rawCmd;
    final rawArgs = (map['args'] as List<String>?) ?? [];
    final description = map['description'] as String?;
    final displayCmd = map['display_cmd'] as bool? ?? true;
    final appendNewline = map['append_newline'] as bool? ?? false;
    // print('cmdArgs: $cmdArgs');

    try {
      return RunnableScript(
        name,
        cmd: cmd,
        args: List<String>.from(rawArgs),
        fileSystem: fileSystem,
        description: description,
        displayCmd: displayCmd,
        appendNewline: appendNewline,
      );
    } catch (e) {
      throw StateError('Failed to parse script, arguments: $map, $fileSystem. Error: $e');
    }
  }

  /// Runs the current script with the given extra arguments.
  Future<int> run(List<String> extraArgs) async {
    final effectiveArgs = args + extraArgs;
    final config = await ScriptRunnerConfig.get(_fileSystem);

    final scrContents = _getScriptContents(config, extraArgs: extraArgs);
    final scrPath = _getScriptPath();

    await _fileSystem.file(scrPath).writeAsString(scrContents);

    if (config.shell.os != OS.windows) {
      final result = await io.Process.run("chmod", ["u+x", scrPath]);
      if (result.exitCode != 0) throw Exception(result.stderr);
    }

    final origCmd = [cmd, ...effectiveArgs.map(_utils.quoteWrap)].join(' ');

    if (displayCmd) {
      print(_utils.colorize('\$ $origCmd', [_utils.TerminalColor.gray]));
    }

    try {
      final exitCode = await _runShellScriptFile(config, scrPath);
      if (appendNewline) {
        print('');
      }
      if (exitCode != 0) {
        final e = io.ProcessException(
          cmd,
          args,
          'Process exited with error code: $exitCode',
          exitCode,
        );
        throw e;
      }
      return exitCode;
    } finally {
      await _fileSystem.file(scrPath).delete();
    }
  }

  Future<int> _runShellScriptFile(
    ScriptRunnerConfig config,
    String scrPath,
  ) async {
    final result = await io.Process.start(
      config.shell.shell,
      [config.shell.shellExecFlag, scrPath],
      environment: {...?config.env, ...?env},
      workingDirectory: workingDir ?? config.workingDir,
      mode: io.ProcessStartMode.inheritStdio,
      includeParentEnvironment: true,
    );
    final exitCode = await result.exitCode;
    return exitCode;
  }

  String _getScriptPath() => _fileSystem.path.join(_fileSystem.systemTempDirectory.path, 'script_runner_$name.sh');

  String _getScriptContents(
    ScriptRunnerConfig config, {
    List<String> extraArgs = const [],
  }) {
    var script = cmd;
    if (args.isNotEmpty || extraArgs.isNotEmpty) {
      script += ' ';
      script += (args + extraArgs).map(_utils.quoteWrap).join(' ').trim();
    }
    switch (config.shell.os) {
      case OS.windows:
        return [
          "@echo off",
          ...preloadScripts.map((e) => 'doskey ${e.name} = "scr ${e.name}"'),
          script,
        ].join('\n');
      case OS.linux:
      case OS.macos:
        return [...preloadScripts.map((e) => "[[ ! \$(which ${e.name}) ]] && alias ${e.name}='scr ${e.name}'"), script]
            .join('\n');
    }
  }
}
