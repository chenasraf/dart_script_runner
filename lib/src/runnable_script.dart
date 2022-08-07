import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:script_runner/src/config.dart';
import 'package:script_runner/src/utils.dart' as utils;
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

    return RunnableScript.fromMap(out, fileSystem: fileSystem);
  }

  /// Generate a runnable script from a normal map as defined in the config.
  factory RunnableScript.fromMap(Map<String, dynamic> map,
      {FileSystem? fileSystem}) {
    final name = map['name'] as String;
    final rawCmd = map['cmd'] as String;
    final cmd = rawCmd.split(' ').first;
    final rawArgs = (map['args'] as List<String>?) ?? [];
    final cmdArgs = utils.splitArgs(rawCmd.substring(cmd.length));
    final description = map['description'] as String?;
    // print('cmdArgs: $cmdArgs');

    return RunnableScript(
      name,
      cmd: cmd,
      args: cmdArgs + List<String>.from(rawArgs),
      fileSystem: fileSystem,
      description: description,
    );
  }

  /// Runs the current script with the given extra arguments.
  Future<dynamic> run(List<String> extraArgs) async {
    final effectiveArgs = args + extraArgs;
    // final argsStr = effectiveArgs.map(_wrap).join(' ');
    var config = await ScriptRunnerConfig.get(_fileSystem);
    final shell = config.shell ?? _getPlatformShell();

    final preRun = preloadScripts
        .map((d) => 'alias ${d.name}=\'dartsc ${d.name}\'')
        .join(';');
    final origCmd = [cmd, ...effectiveArgs.map(_wrap)].join(' ');
    final passCmd = '$preRun; eval \'$origCmd\'';

    print('Running: $origCmd');
    // print("Before parse $cmd $args");

    try {
      final result = await io.Process.start(
        shell,
        [
          '-c',
          passCmd,
        ],
        environment: {...?config.env, ...?env},
        workingDirectory: workingDir ?? config.workingDir,
      );
      result.stdout.listen((event) {
        io.stdout.write(String.fromCharCodes(event));
      });
      result.stderr.listen((event) {
        io.stdout.write(String.fromCharCodes(event));
      });
      final exitCode = await result.exitCode;
      if (exitCode != 0) {
        // final stack = StackTrace.current;
        final e = io.ProcessException(
            cmd, args, 'Process exited with error code: $exitCode', exitCode);
        throw e;
      }
    } catch (e) {
      rethrow;
    }
  }

  static String _getPlatformShell() {
    if (io.Platform.isWindows) {
      return 'cmd.exe';
    }
    return '/bin/sh';
  }
}

String _wrap(String arg) {
  if (arg.contains(' ')) {
    return '"$arg"';
  }
  return arg;
}
