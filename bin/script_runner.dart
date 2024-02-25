import 'dart:io' as io;

import 'package:script_runner/src/base.dart';
import 'package:script_runner/src/utils.dart';

/// Main entrypoint for CMD script runner.
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    printColor('No script command provided. Use -h to see available commands.', [TerminalColor.red]);
    return;
  }
  final scriptCmd = args.first;
  final scriptArgs = args.sublist(1);
  try {
    final code = await runScript(scriptCmd, scriptArgs);
    io.exit(code);
  } catch (e, stack) {
    printColor('$e\n$stack', [TerminalColor.red]);
    if (e is io.ProcessException) {
      io.exit(e.errorCode);
    }
  }
}
