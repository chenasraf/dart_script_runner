import 'package:script_runner/src/base.dart';

Future<void> main(List<String> args) async {
  final scriptCmd = args.first;
  final scriptArgs = args.sublist(1);
  return runScript(scriptCmd, scriptArgs);
}
