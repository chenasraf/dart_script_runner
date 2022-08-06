import 'package:script_runner/src/script_runner_base.dart';

Future<void> main(List<String> args) async {
  final scriptCmd = args.first;
  final scriptArgs = args.sublist(0, args.length - 1);
  await runScript(scriptCmd, scriptArgs);
}
