# drun example

This folder contains a contrived example that shows how you could structure your
makefiles, it is a working example of all features and functionality.

> Okay actually this is still a WIP, __almost__ all features and
> functionality have an example you can play with.

<https://github.com/brad-jones/drun/tree/master/example>

## The basics

```dart
import 'package:drun/drun.dart';

/// Start off by redirecting your main method to the drun method
Future<void> main(List<String> argv) => drun(argv);

/// Then just create functions and execute them like: `drun my-task`
///
/// HINT: docblocks are used to generate help text on the command line.
/// try `drun my-task --help`
void myTask() {
  print('Mello World');
}

/// Both sync and async functions are supported.
Future<void> myTaskAsync() async {
  await Future.delayed(Duration(seconds: 3));
  print('Mello World');
}

/// Private functions do not get exposed as CLI tasks.
/// The same is true for anything that is imported.
///
/// Only public functions in files named "Makefile.dart"
/// will be considered as tasks.
void _myPrivateTask() {}

/// Tasks can have parameters.
/// call me like: `drun my-task-with-parameter --foo-bar abc123`
///
/// * [fooBar] Parameters may optionally be documented like this.
///   Multiple lines are allowed.
///
///   Parameters can be of the following types: bool, int, double, String
///   List<int>, List<double>, List<String>
void myTaskWithParameter(String fooBar) {
  print('fooBar=${fooBar}');
}

/// Tasks can have parameters with default values.
///
/// NOTE: Optional parameters are supported, named parameters are not!
void myTaskWithParameterDefault([String fooBar = 'abc123']) {
  print('fooBar=${fooBar}');
}

/// Tasks can have have flags (as opposed to cli options).
///
/// Boolean flags do not accept values, they are either present donoting true
/// or they are absent denoting false.
///
/// call me like: `drun my-task-with-bool-flag --debug-mode`
void myTaskWithBoolFlag(bool debugMode) {
  print('debugMode=${debugMode}');
}

/// Tasks can have paramters that are lists.
///
/// These are represented as CSV strings on the command line.
/// Only List<int>, List<double>, List<String> is currenty supported.
///
/// call me like: `drun my-task-with-csv-list --numbers "1,2,3,4,5,6,7,8,9"`
void myTaskWithCsvList(List<int> numbers) {
  print('numbers=${numbers}');
}

/// Parameters can be abbreviated.
/// call me like: `drun my-task-with-abbreviated-parameter -f abc123`
void myTaskWithAbbreviatedParameter(@Abbr('f') String foobar) {
  print('foobar=${foobar}');
}

/// Parameters can get their values from the environment.
/// call me like: `FOO_BAR=abc123 drun my-task-with-env-parameter`
///
/// A CLI option will always take precedence over an environment variable.
void myTaskWithEnvParameter(@Env('FOO_BAR') String foobar) {
  print('foobar=${foobar}');
}

/// Parameters can be restricted to specfic set of values.
///
/// These calls are valid:
/// * `drun my-task-with-value-validation --foobar foo`
/// * `drun my-task-with-value-validation --foobar bar`
///
/// These calls are invalid:
/// * `drun my-task-with-value-validation --foobar abc`
/// * `drun my-task-with-value-validation --foobar xyz`
void myTaskWithValueValidation(@Values(['foo', 'bar']) String foobar) {
  print('foobar=${foobar}');
}
```

## Using the task dsl

```dart
/// Runs a task using the drun task() helper function
///
/// Up until now all tasks have been plain dart functions.
/// Drun provides additional functionality through the [task] wrapper.
/// It is totally optional if you use this, the next few examples show
/// off what is possible.
Future myTaskThatUsesTaskHelper() => task((drun) {
      drun.log('Hello');
    });

/// An example of using drun's logging, by default all log messages output from
/// a task are prefixed with the task's name. This results in output similar to
/// tools like `docker-compose` when many tasks are running concurrently.
///
/// HINT: try running this task with `--log-buffered` to see the alternative
Future myTaskThatLogs() => task((drun) => Future.wait([
      myTaskThatLogsFoo(),
      myTaskThatLogsBar(),
      myTaskThatLogsBaz(),
    ]));
Future myTaskThatLogsFoo() => task((drun) => drun.log('i did some work'));
Future myTaskThatLogsBar() => task((drun) => drun.log('i did some work'));
Future myTaskThatLogsBaz() => task((drun) {
      drun.logPrefix = 'custom-prefix';
      drun.log('i did some work');
    });

/// An example of running the same task many times but only having it truly
/// execute once. This is very handy for constructing complex build chains
/// where multiple tasks may all depend on a common task.
Future myTaskThatRunsOnceExample() => task((drun) => Future.wait([
      myTaskThatRunsOnce(),
      myTaskThatRunsOnce(),
      myTaskThatRunsOnce(),
    ]));
Future myTaskThatRunsOnce() => task((drun) => drun.once(
      () => print('you should only see me printed one time'),
    ));

/// Example of using `exe` which is a wrapper around the `dexeca` project.
///
/// While you can of course use native dart code to do things, more often than
/// you will probably shell out to other processes in order to do your work.
///
/// The `drun.exe` & `drun.exeSync` methods help you do this easily.
/// Of course if your require lower level control feel free to use the
/// `dexeca` function directly.
///
/// see: <https://pub.dev/packages/dexeca>
Future<void> myTaskThatRunsAChildProc() => task(
      (drun) => drun.exe('ping', drun.pingArgs('1.1.1.1')),
    );

/// Example of using the `exists` functionality.
///
/// This is handy for ensuring tasks that generate artifacts only run when the
/// artifact doesn't already exist.
Future<void> myTaskThatRunsIfNotFound() => task((drun) async {
      if (!await drun.exists(['./bin/**/foo'])) {
        print('You should only see me if the '
            'file `./bin/baz/foo` does not exist');
        await File('./bin/baz/foo').create(recursive: true);
      }
    });

/// Example of using the `changed` functionality.
///
/// This is handy for ensuring tasks that generate artifacts from source files
/// only run when those source files have changed since the last execution.
Future<void> myTaskThatRunsIfChanged() => task((drun) async {
      if (await drun.changed(['./Makefile.dart'])) {
        print('You should only see me if this '
            'file has changed since the last time this task was run.\n'
            'Perhaps just edit this message to test this out :)');
      }
    });

/// Example of using the `notFoundOrChanged` functionality.
///
/// It's fairly common to want to combine both [exists] and [changed] so here
/// is an example that does just that.
Future<void> myTaskThatRunsIfNotFoundOrChanged() => task((drun) async {
      if (await drun.notFoundOrChanged(
        ['./bin/**/foo'],
        ['./Makefile.dart'],
      )) {
        print('You should only see me if the '
            'file `./bin/baz/foo` does not exist');
        print('OR');
        print('You should only see me if this '
            'file has changed since the last time this task was run.\n'
            'Perhaps just edit this message to test this out :)');
        await File('./bin/baz/foo').create(recursive: true);
      }
    });
```
