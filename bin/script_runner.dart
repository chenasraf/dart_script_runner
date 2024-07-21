import 'dart:io' as io;

import 'package:script_runner/base.dart';
import 'package:script_runner/utils.dart';

/// Main entrypoint for CMD script runner.
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    printColor(
        'No script command provided. Use -h or -ls to see available commands.',
        [TerminalColor.red]);
    return;
  }
  final scriptCmd = args.first;
  final scriptArgs = args.sublist(1);
  try {
    final code = await runScript(scriptCmd, scriptArgs);
    io.exit(code);
  } catch (e, stack) {
    if (e is ScriptError) {
      printColor(e.toString(), [TerminalColor.red]);
    } else if (e is io.ProcessException) {
      printColor(
          'Error in script "$scriptCmd": ${e.message}', [TerminalColor.red]);
      io.exit(e.errorCode);
    } else {
      printColor('Error executing script: $e\n$stack', [TerminalColor.red]);
      io.exit(1);
    }
  }
}
