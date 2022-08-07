<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->

# script_runner

A general script runner for dart projects - run all your project-related scripts in a portable,
simple config.

## Features

- **Easy:** Provides an easy to use config for project-related scripts, similar to what NPM allows
  in its `scripts` section of `package.json`.
- **Portable:** The scripts are meant to be portable and can reference each-other, to maximize the
  flexibility of creating configurable script execution orders &amp; dependencies.
- **Self-documenting:** Removes the need to document where and how to load different types of
  scripts on your project. Unify all your runners into 1 config that lets you freely call everything
  on-demand, and also supply an auto-generated documentation using `dartsc -h`.

## Getting started

You can install this package globally for the most easy usage.

```shell
pub global activate script_runner
```

Once activated, you can use the supplied `dartsc` executable to directly call scripts from any
project you are currently in.

## Usage

Add the `script_runner` config to your `pubspec.yaml` under `script_runner`, or alternatively you
can use a separate config file named `script_runner.yaml` at the root of your project.

This is the structure of a config:

```yaml
# only use this key if you are inside pubspec.yaml. Otherwise, it's not needed
script_runner:
  # The shell to run all of the scripts with. (optional)
  shell: /bin/sh
  # The current working directory to run the scripts in. (optional)
  cwd: .
  # Environment variables to add to the running shells in the scripts. (optional)
  env:
    MY_ENV: my-value
    # ...
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
      # Optional - will be used in docs when using `dartsc -h`.
      description: Run my script
      # Optional - overrides the root-level config
      cwd: .
      # Optional - overrides the root-level config
      env:
        MY_ENV: my-value
        # ...
      # The script to run. You can supply the args directly here, or split into
      # `cmd` and `args` as a list.
      cmd: my_scr 'arg1'
      # Optional - if supplied, will be appended as arguments to `cmd`.
      args:
        - arg2
        - arg3
```
