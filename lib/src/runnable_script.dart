import 'dart:convert';
import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:script_runner/src/config.dart';
// ignore: no_leading_underscores_for_library_prefixes
import 'package:script_runner/src/utils.dart' as _utils;
import 'package:yaml/yaml.dart' as yaml;

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

  /// When set to [true], the command will not print "Running: ...". This is useful for using the output in
  /// other scripts.
  ///
  /// Defaults to [false].
  final bool suppressHeaderOutput;

  /// When set to [true], the command will end with a newline. This is useful for using the output in other scripts.
  ///
  /// Defaults to [false].
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
    this.suppressHeaderOutput = false,
    this.appendNewline = false,
  }) : _fileSystem = fileSystem ?? LocalFileSystem();

  /// Generate a runnable script from a yaml loaded map as defined in the config.
  factory RunnableScript.fromYamlMap(yaml.YamlMap map,
      {FileSystem? fileSystem}) {
    final out = <String, dynamic>{};

    if (map['name'] == null && map.keys.length == 1) {
      out['name'] = map.keys.first;
      out['cmd'] = map.values.first;
    } else {
      out.addAll(map.cast<String, dynamic>());
      out['args'] =
          (map['args'] as yaml.YamlList?)?.map((e) => e.toString()).toList();
      out['env'] = (map['env'] as yaml.YamlMap?)?.cast<String, String>();
    }
    try {
      return RunnableScript.fromMap(out, fileSystem: fileSystem);
    } catch (e) {
      throw StateError(
          'Failed to parse script, arguments: $map, $fileSystem. Error: $e');
    }
  }

  /// Generate a runnable script from a normal map as defined in the config.
  factory RunnableScript.fromMap(
    Map<String, dynamic> map, {
    FileSystem? fileSystem,
  }) {
    final name = map['name'] as String;
    final rawCmd = map['cmd'] as String;
    final cmd = rawCmd.split(' ').first;
    final rawArgs = (map['args'] as List<String>?) ?? [];
    final cmdArgs = _utils.splitArgs(rawCmd.substring(cmd.length));
    final description = map['description'] as String?;
    final suppressHeaderText = map['suppress_header_output'] as bool? ?? false;
    final appendNewline = map['append_newline'] as bool? ?? false;
    // print('cmdArgs: $cmdArgs');

    try {
      return RunnableScript(
        name,
        cmd: cmd,
        args: cmdArgs + List<String>.from(rawArgs),
        fileSystem: fileSystem,
        description: description,
        suppressHeaderOutput: suppressHeaderText,
        appendNewline: appendNewline,
      );
    } catch (e) {
      throw StateError(
          'Failed to parse script, arguments: $map, $fileSystem. Error: $e');
    }
  }

  /// Runs the current script with the given extra arguments.
  Future<dynamic> run(List<String> extraArgs) async {
    final effectiveArgs = args + extraArgs;
    final config = await ScriptRunnerConfig.get(_fileSystem);

    final scrContents = _getScriptContents(config, extraArgs: extraArgs);
    final scrPath = _getScriptPath();

    await _fileSystem.file(scrPath).writeAsString(scrContents);

    if (config.shell.os != OS.windows) {
      final result = await io.Process.run("chmod", ["u+x", scrPath]);
      if (result.exitCode != 0) throw Exception(result.stderr);
    }

    final origCmd = [cmd, ...effectiveArgs.map(_utils.wrap)].join(' ');

    if (!suppressHeaderOutput) {
      print('Running: $origCmd');
    }

    try {
      final exitCode = await _runShellScriptFile(config, scrPath);
      if (appendNewline) {
        print('');
      }
      if (exitCode != 0) {
        final e = io.ProcessException(
            cmd, args, 'Process exited with error code: $exitCode', exitCode);
        throw e;
      }
    } catch (e) {
      rethrow;
    } finally {
      await _fileSystem.file(scrPath).delete();
    }
  }

  Future<int> _runShellScriptFile(ScriptRunnerConfig config, scrPath) async {
    final result = await io.Process.start(
      config.shell.shell,
      [config.shell.shellExecFlag, scrPath],
      environment: {...?config.env, ...?env},
      workingDirectory: workingDir ?? config.workingDir,
    );
    result.stdout.listen((event) {
      io.stdout.write(Utf8Decoder().convert(event));
    });
    result.stderr.listen((event) {
      io.stdout.write(Utf8Decoder().convert(event));
    });
    final exitCode = await result.exitCode;
    return exitCode;
  }

  String _getScriptPath() => _fileSystem.path
      .join(_fileSystem.systemTempDirectory.path, 'script_runner_$name.sh');

  String _getScriptContents(ScriptRunnerConfig config,
      {List<String> extraArgs = const []}) {
    final script = "$cmd ${(args + extraArgs).map(_utils.wrap).join(' ')}";
    switch (config.shell.os) {
      case OS.windows:
        return [
          "@echo off",
          ...preloadScripts.map((e) => 'doskey ${e.name} = "scr ${e.name}"'),
          script,
        ].join('\n');
      case OS.linux:
      case OS.macos:
        return [
          ...preloadScripts.map((e) => "alias ${e.name}='scr ${e.name}'"),
          script
        ].join('\n');
    }
  }
}
