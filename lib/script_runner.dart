/// Support for doing something awesome.
///
/// More dartdocs go here.
library script_runner;

import 'package:script_runner/src/script_runner_base.dart' as _base;

export 'src/script_runner_base.dart' show runScript, ScriptRunnerConfig, RunnableScript;

Future<void> main(List<String> args) async {
  final scriptCmd = args.first;
  final scriptArgs = args.sublist(1);
  await _base.runScript(scriptCmd, scriptArgs);
}
