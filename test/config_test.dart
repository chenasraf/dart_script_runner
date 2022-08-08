import 'dart:io';

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
        await _writePubspec(fs);
      });

      test('works', () async {
        final conf = await ScriptRunnerConfig.get(fs);
        final testScr = conf.scriptsMap['test']!;
        expect(testScr.name, 'test');
        expect(testScr.cmd, 'echo');
        expect(testScr.args, ['hello']);
      });
    });

    group('script_runner.yaml loader', () {
      setUp(() async {
        fs = MemoryFileSystem();
        await _writeCustomConf(fs);
      });

      test('works', () async {
        final conf = await ScriptRunnerConfig.get(fs);
        final testScr = conf.scriptsMap['test']!;
        expect(testScr.name, 'test');
        expect(testScr.cmd, 'echo');
        expect(testScr.args, ['hello']);
      });
    });
  });

  group('ScriptRunnerShellConfig', () {
    group('plain shell', () {
      setUp(() async {
        fs = MemoryFileSystem();
        await _writePubspec(
          fs,
          [
            'script_runner:',
            '  shell: /bin/zsh',
            '  scripts:',
            '    - name: test',
            '      cwd: .',
            '      cmd: echo "hello"',
          ].join('\n'),
        );
      });

      test('works', () async {
        final conf = await ScriptRunnerConfig.get(fs);
        expect(conf.shell.shell, '/bin/zsh');
      });
    });

    group('per os config', () {
      setUp(() async {
        fs = MemoryFileSystem();
        await _writePubspec(
          fs,
          [
            'script_runner:',
            '  shell:',
            '    linux: /bin/zsh',
            '    macos: /bin/bash',
            '    windows: powershell.exe',
            '  scripts:',
            '    - name: test',
            '      cwd: .',
            '      cmd: echo "hello"',
          ].join('\n'),
        );
      });

      test('works', () async {
        final conf = await ScriptRunnerConfig.get(fs);
        final osShells = {
          'linux': '/bin/zsh',
          'macos': '/bin/bash',
          'windows': 'powershell.exe',
        };
        final myOsShell = Platform.isWindows
            ? 'windows'
            : Platform.isMacOS
                ? 'macos'
                : 'linux';
        expect(conf.shell.windows, osShells['windows']!);
        expect(conf.shell.macos, osShells['macos']!);
        expect(conf.shell.linux, osShells['linux']!);
        expect(conf.shell.shell, osShells[myOsShell]!);
      });
    });
  });
}

Future<void> _writeCustomConf(FileSystem fs, [String? contents]) async {
  final pubFile =
      fs.file(path.join(fs.currentDirectory.path, 'script_runner.yaml'));
  pubFile.create(recursive: true);
  await pubFile.writeAsString(
    contents ??
        [
          'shell: /bin/sh',
          'scripts:',
          '  - name: test',
          '    cwd: .',
          '    cmd: echo "hello"',
        ].join('\n'),
  );
}

Future<void> _writePubspec(FileSystem fs, [String? contents]) async {
  final pubFile = fs.file(path.join(fs.currentDirectory.path, 'pubspec.yaml'));
  pubFile.create(recursive: true);
  await pubFile.writeAsString(
    contents ??
        [
          'script_runner:',
          '  shell: /bin/sh',
          '  scripts:',
          '    - name: test',
          '      cwd: .',
          '      cmd: echo "hello"',
        ].join('\n'),
  );
}
