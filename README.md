<h1>Dart Script Runner</h1>

A general script runner for any type of project - run all your project-related scripts and commands
in a portable, simple config.

<details>
<summary>Table of contents</summary>

- [What for?](#what-for)
- [Features](#features)
- [Getting started](#getting-started)
- [Usage](#usage)
  - [Normal usage (config file)](#normal-usage-config-file)
  - [Advanced usage (Dart import)](#advanced-usage-dart-import)
- [Contributing](#contributing)

</details>

---

## What for?

You might use it to chain multiple commands into a unified build process, format and lint your
documents, or more.

This project was developed with inspiration from NPM's `scripts` inside `package.json` and is meant
to work similarly, though it can be customized to fit your needs more specifically.

## Features

- **Easy:** Provides an easy to use config for project-related scripts, similar to what NPM allows
  in its `scripts` section of `package.json`.
- **Portable:** The scripts are meant to be portable and can reference each-other, to maximize the
  flexibility of creating configurable script execution orders &amp; dependencies. Also you don't
  have to be on a dart project, just add a `script_runner.yaml` file to any folder and you're good
  to go!
- **Self-documenting:** Removes the need to document where and how to load different types of
  scripts on your project, or create custom script loaders and more time-wasting pipeline. Unify all
  your runners into 1 config that lets you freely call everything on-demand from any type of
  project, and also supply an auto-generated documentation using `scr -h`.

## Getting started

You can install this package globally for the most easy usage.

```shell
pub global activate script_runner
```

Once activated, you can use the supplied `scr` executable to directly call scripts from any project
you are currently in.

```shell
scr my-script ...args
```

You can also install this package as a dependency and build/run your own script lists. (but why
would you?)

## Usage

### Normal usage (config file)

Add the `script_runner` config to your `pubspec.yaml` under `script_runner`, or alternatively you
can use a separate config file named `script_runner.yaml` at the root of your project.

A bare-bones example looks like this:

```yaml
script_runner:
  scripts:
    - doc: dart doc
    - publish: dart pub publish
    - deploy: doc && publish
    - auto-fix: dart fix --apply
```

This is the full structure of a config:

```yaml
# only use this key if you are inside pubspec.yaml. Otherwise, it's not needed
script_runner:
  # The shell to run all of the scripts with. (optional - defaults to OS shell)
  shell: /bin/sh
  # Use a map to define shell per OS, when not specified falls back to "default":
  # (optional)
  shell:
    default: /bin/sh
    windows: cmd.exe
    macos: /bin/sh
    linux: /bin/sh
  # The current working directory to run the scripts in. (optional)
  cwd: .
  # Environment variables to add to the running shells in the scripts. (optional)
  env:
    MY_ENV: my-value
    # ...
  # The amount of characters to allow before considering the line over when
  # printing help usage (scr -h)
  line_length: 80
  # Scripts support either a short-format config, or a more verbose one with
  # more possible argument to pass to each script.
  # Scripts can reference other scripts, e.g. `script1` can reference
  # `script2` by calling it directly in the command:
  # - script1: echo '1'
  # - name: script2
  #   cmd: script1 && echo '2'
  # Running `script1` will echo 1 and then 2.
  scripts:
    # short format - only name + cmd & args:
    - my-short-script: my_scr arg1 arg2 arg3 && echo 'Done!'

    # more verbose config, for extra configuration
    - name: my-script
      # Optional - will be used in docs when using `scr -h`.
      description: Run my script
      # Optional - overrides the root-level config
      cwd: .
      # Optional - overrides the root-level config
      env:
        MY_ENV: my-value
        # ...
      # Use to suppress the "Running: ..." output before running the command
      # to make it possible to use ouput for other scripts
      suppress_header_output: true
      # The script to run. You can supply the args directly here, or split into
      # `cmd` and `args` as a list.
      cmd: my_scr 'arg1'
      # Optional - if supplied, will be appended as arguments to `cmd`.
      args:
        - arg2
        - arg3
```

For this config, running `scr my-script` will run the appropriate script, filling the env and
changing the working directory as needed.

More arguments can be passed during the call to the script, which will then be piped to the original
`cmd`.

### Advanced usage (Dart import)

If you want to build your own configs dynamically in Dart, you can import the package and create
your own runners and scripts:

```dart
import 'package:script_runner/script_runner.dart';

void main() {
  // Directly run a script from config, same as running `scr`
  runScript('my-script', ['arg1', 'arg2'])

  // Build your own configurations and scripts and run them as you please:
  final runner = ScriptRunnerConfig(
    shell: '/bin/zsh',
    scripts: [
      RunnableScript(
        name: 'my-script',
        cmd: 'echo',
        args: ['Hello world'],
      ),
    ],
  );

  runner.scriptsMap['my-script'].run();
}
```

## Contributing

I am developing this package on my free time, so any support, whether code, issues, or just stars is
very helpful to sustaining its life. If you are feeling incredibly generous and would like to donate
just a small amount to help sustain this project, I would be very very thankful!

<a href='https://ko-fi.com/casraf' target='_blank'>
  <img height='36' style='border:0px;height:36px;'
    src='https://cdn.ko-fi.com/cdn/kofi1.png?v=3'
    alt='Buy Me a Coffee at ko-fi.com' />
</a>

I welcome any issues or pull requests on GitHub. If you find a bug, or would like a new feature,
don't hesitate to open an appropriate issue and I will do my best to reply promptly.

If you are a developer and want to contribute code, here are some starting tips:

1. Fork this repository
2. Run `dart pub get`
3. Make any changes you would like
4. Create tests for your changes
5. Update the relevant documentation (readme, code comments)
6. Create a PR on upstream
