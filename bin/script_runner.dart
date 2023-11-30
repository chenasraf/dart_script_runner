import 'package:script_runner/src/base.dart';
import 'package:script_runner/src/utils.dart';

/// Main entrypoint for CMD script runner.
Future<void> main(List<String> args) async {
  final scriptCmd = args.first;
  final scriptArgs = args.sublist(1);
  try {
    await runScript(scriptCmd, scriptArgs);
  } catch (e) {
    printColor('$e', [TerminalColor.red]);
  }
}
