// ignore: no_leading_underscores_for_library_prefixes
import 'dart:io';

import 'package:script_runner/src/config.dart';
import 'package:script_runner/src/utils.dart' as utils;
import 'package:yaml/yaml.dart' as yaml;

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
    final cmdArgs = utils.splitArgs(rawCmd.substring(cmd.length));
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
    var config = await ScriptRunnerConfig.get();
    final shell = config.shell ?? '/bin/sh';

    final preRun = dependencies.map((d) => 'alias ${d.name}=\'dartsc ${d.name}\'').join(';');
    final origCmd = [cmd, ...effectiveArgs.map(_wrap)].join(' ');
    final passCmd = '$preRun; eval \'$origCmd\'';

    print('Running: $origCmd');
    // print("Before parse $cmd $args");

    try {
      final result = await Process.start(
        shell,
        [
          '-c',
          passCmd,
        ],
        environment: config.env,
        workingDirectory: config.workingDir,
      );
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
    } catch (e) {
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
