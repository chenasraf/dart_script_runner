import 'package:script_runner/script_runner.dart';
import 'package:test/test.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:path/path.dart' as path;

void main() {
  late FileSystem fs;
  group('ScriptRunnerConfig', () {
    group('pubspec.yaml loader', () {
      setUp(() async {
        fs = MemoryFileSystem();
        final pubFile = fs.file(path.join(fs.currentDirectory.path, 'pubspec.yaml'));
        pubFile.create(recursive: true);
        await pubFile.writeAsString(
          [
            'script_runner:',
            '  shell: /bin/sh',
            '  scripts:',
            '    - name: test',
            '      cwd: .',
            '      cmd: echo "hello"',
          ].join('\n'),
        );
      });

      test('Works', () async {
        final conf = await ScriptRunnerConfig.get(fs);
        expect(conf.scriptsMap['test']!.name, 'test');
        expect(conf.scriptsMap['test']!.cmd, 'echo');
        expect(conf.scriptsMap['test']!.args, ['hello']);
      });
    });
  });
}
