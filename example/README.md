# drun example

This folder contains a contrived example that shows how you could structure your
makefiles, it is a working example of all features and functionality.

<https://github.com/brad-jones/drun/tree/master/example>

## The basics

```dart
import 'package:drun/drun.dart';

/// Start off by redirecting your main method to the drun method
Future<void> main(List<String> argv) => drun(argv);

/// Then just create functions and execute them like: `drun my-task`
///
/// HINT: docblocks are used to generate help text on the command line.
///       try `drun my-task --help`
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

/// Parameters can be restricted to a specfic set of values.
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

/// Tasks can accept any number of positional arguments.
///
/// In order to access unparsed CLI arguments you can use an optional parameter
/// of the type `List<String>` with the name `argv`. Any other parameter name
/// will not work as expected.
///
/// This is handy for proxing another cli tool, usage might look like:
/// `drun my-task-with-positional-args --foo bar -- abc 123 --opt-a=xyz -z`
///
/// If `--` is not used to seperate the unparsed arguments you can not make use
/// of flag syntax (eg: `--abc`) because drun will try and parse that against
/// the task and will error with `Could not find an option named "abc"`.
///
/// So something like `drun my-task-with-positional-args --foo bar 123` might
/// be valid, something like `drun my-task-with-positional-args --foo bar --123`
/// probably won't be.
void myTaskWithPositionalArgs(String foo, [List<String> argv]) {
  print('foo=${foo}');
  argv.asMap().forEach((k, v) => print('pos ${k} = ${v}'));
}
```

## Using the task dsl

```dart
/// Runs a task using the drun [task] helper function
///
/// Up until now all tasks have been plain dart functions.
/// Drun provides additional functionality through the [task] wrapper and
/// the injected Drun class instance. It is totally optional if you use this,
/// the next few examples show off what is possible.
///
/// This Drun DSL makes heavy use of function expressions (ie: arrow syntax).
/// see: <https://dart.dev/guides/language/language-tour#functions>
///
/// HINT: When using the [task] wrapper it will always return a `Future<T>` even
///       if the provided anonymous function is synchronous, hence the reason
///       this task returns a `Future` and not `void`.
///
/// see: <https://pub.dev/documentation/drun/latest/drun/task.html>
Future myTaskThatUsesTaskHelper() => task((drun) {
  drun.log('Hello');
});

/// An example of consuming global options.
///
/// HINT: These are defined in `Makefile.opts.dart`
Future myTaskWithGlobalOptions() => task((drun) {
  drun.log(drun.foo);
  drun.log(drun.bar.toString());
  drun.log(drun.baz);
  drun.log(drun.abc);
  drun.log(drun.xyz);
  drun.log(drun.foobar);
});

/// Example of using `deps`.
///
/// Alternatively this example could easily be re-written as:
///
/// ```dart
/// Future myTaskThatDependsOnAnother() => task((drun) async {
///   var tasks = [_aPrivateTask()];
///   if (false) {
///     tasks.add(_aPrivateTask());
///   }
///   await drun.deps(tasks);
///   drun.log('doing more work');
/// });
/// ```
///
/// HINT: `drun.deps` is just an alias for `Future.wait(eagerError:true)`
///
/// see: <https://pub.dev/documentation/drun/latest/drun/Drun/deps.html>
Future myTaskThatDependsOnAnother() => task((drun) => drun.deps([
  _aPrivateTask(),
  // conditional tasks can easily be added by using the ternary operator
  false ? _aPrivateTask() : null,
]).then(
  (_) => drun.log('doing more work')
));

/// Oh and if you do use the [task] wrapper, you can define private tasks like
/// this one. These are not callable via the CLI nor will they show up in any
/// help text.
///
/// This pattern is most handy when you want to have a distinct log prefix
/// with-in a single "callable" task.
Future _aPrivateTask() => task((drun) => drun.log('doing work'));

/// An example of using drun's logging, by default all log messages output from
/// a task are prefixed with the task's name. This results in output similar to
/// tools like `docker-compose` when many tasks are running concurrently.
///
/// HINT: try running this task with `--log-buffered` to see the alternative
///
/// see: <https://pub.dev/documentation/drun/latest/drun/Drun/log.html>
Future myTaskThatLogs() => task((drun) => drun.deps([
  _myTaskThatLogsFoo(),
  _myTaskThatLogsBar(),
  _myTaskThatLogsBaz(),
]));
Future _myTaskThatLogsFoo() => task((drun) => drun.log('i did some work'));
Future _myTaskThatLogsBar() => task((drun) => drun.log('i did some work'));

/// You may annotate a task to set a custom log prefix if the reflected value
/// is not sufficient.
@LogPrefix('custom-prefix')
Future _myTaskThatLogsBaz() => task((drun) => drun.log('i did some work'));

/// An example of running the same task many times but only having it truly
/// execute once. This is very handy for constructing complex build chains
/// where multiple tasks may all depend on a common task.
///
/// see: <https://pub.dev/documentation/drun/latest/drun/Drun/once.html>
Future myTaskThatRunsOnce() => task((drun) => drun.deps([
  _myTaskThatRunsOnce(),
  _myTaskThatRunsOnce(),
  _myTaskThatRunsOnce(),
]));
Future _myTaskThatRunsOnce() => task((drun) => drun.once(
  () => drun.log('you should only see me printed one time')
));

/// Example of using `exe` which is a wrapper around the `dexeca` project.
///
/// While you can of course use native dart code to do things, more often than
/// not you will probably shell out to other processes in order to do your work.
///
/// The `drun.exe` & `drun.exeSync` methods help you do this easily.
/// Of course if your require lower level control feel free to use the
/// `dexeca` function directly.
///
/// HINT: This is also an example of extending the Drun DSL with `drun.pingArgs`
///       it is defined in `Makefile.utils.dart`.
///
/// see: <https://pub.dev/documentation/drun/latest/drun/Drun/exe.html>
/// also: <https://pub.dev/packages/dexeca>
Future myTaskThatRunsAChildProc() => task(
  (drun) => drun.exe('ping', drun.pingArgs('1.1.1.1'))
);

/// Example of using the `exists` functionality.
///
/// This is handy for ensuring tasks that generate artifacts only run when the
/// artifact doesn't already exist.
///
/// see: <https://pub.dev/documentation/drun/latest/drun/Drun/exists.html>
Future myTaskThatRunsIfNotFound() => task((drun) async {
  if (!await drun.exists(['./bin/**/foo'])) {
    print('You should only see me if the file `./bin/baz/foo` does not exist');
    await File('./bin/baz/foo').create(recursive: true);
  }
});

/// Example of using the `changed` functionality.
///
/// This is handy for ensuring tasks that generate artifacts from source files
/// only run when those source files have changed since the last execution.
///
/// see: <https://pub.dev/documentation/drun/latest/drun/Drun/changed.html>
Future myTaskThatRunsIfChanged() => task((drun) async {
  if (await drun.changed(['./Makefile.dart'])) {
    print(
      'You should only see me if this file has changed '
      'since the last time this task was run.\n'
      'Perhaps just edit this message to test this out :)'
    );
  }
});

/// Example of using the `notFoundOrChanged` functionality.
///
/// It's fairly common to want to combine both [exists] and [changed] so here
/// is an example that does just that.
///
/// see: <https://pub.dev/documentation/drun/latest/drun/Drun/notFoundOrChanged.html>
Future myTaskThatRunsIfNotFoundOrChanged() => task((drun) async {
  if (await drun.notFoundOrChanged(
    ['./bin/**/foo'],
    ['./Makefile.dart'],
  )) {
    print('You should only see me if the file `./bin/baz/foo` does not exist');
    print('OR');
    print(
      'You should only see me if this file has changed '
      'since the last time this task was run.\n'
      'Perhaps just edit this message to test this out :)'
    );
    await File('./bin/baz/foo').create(recursive: true);
  }
});

/// Example of using `realpath` functionality.
///
/// Many times when writing tasks you will want to refer to file & folder paths.
/// drun will ensure the current working directory is the same as the location
/// of the executing `Makefile.dart` and for simple cases this will be sufficient.
///
/// However when many makefiles are imported and combined together then we need
/// a way to ensure paths are standardized across all makefiles due to the ability
/// to execute imported makefiles independently.
///
/// This task is simply an alias for the same task defined in
/// `./example/projects/bar/Makefile.dart`.
///
/// So you should be able to execute `drun my-task-that-uses-real-path` both at
/// the root of this `./example` and inside `./example/projects/bar` to see the
/// problem and the solution.
///
/// _PWD=./example_
/// ```
/// drun my-task-that-uses-real-path
/// bar:my-task-that-uses-real-path | /home/brad.jones/Projects/.github
/// bar:my-task-that-uses-real-path | /home/brad.jones/Projects/Personal/drun/.github
/// ```
///
/// _PWD=./example/projects/bar_
/// ```
/// drun my-task-that-uses-real-path
/// my-task-that-uses-real-path | /home/brad.jones/Projects/Personal/drun/.github
/// my-task-that-uses-real-path | /home/brad.jones/Projects/Personal/drun/.github
/// ```
///
/// Essentially when the path starts with `!` it will be replaced by the
/// projects root dir. Which is determined by recursing up the filesystem
/// looking for a `.git` folder.
///
/// All built-in drun methods that accept paths pass the paths through
/// `realpath` for you.
///
/// HINT: If this logic is not suitable (eg: git is not being used) then you
///       may provide your very own `rootFinder` function.
///
/// see: <https://pub.dev/documentation/drun/latest/drun/Drun/realpath.html>
Future myTaskThatUsesRealPath() => bar.myTaskThatUsesRealPath();

/// Example of using `copy` functionality.
///
/// Copying files and folders is common task that you will perform.
/// The `copy` method accepts a `src` and `dst` that can be a single file
/// or a folder.
///
/// The `copy` method will log what it copies by outputing `src => dst` lines.
///
/// HINT: If copying a folder you can supply a list of glob patterns
///       to exclude from the `src`.
///
/// see: <https://pub.dev/documentation/drun/latest/drun/Drun/copy.html>
Future myTaskThatCopies() => task(
  (drun) => drun.copy('!/example/.env', '!/example/.env.copy')
);

/// Example of using `move` functionality.
///
/// Moving files and folders is common task that you will perform.
/// The `move` method accepts a `src` and `dst` that can be a single file
/// or a folder.
///
/// The `move` method will log what it moves by outputing `src => dst` lines.
///
/// see: <https://pub.dev/documentation/drun/latest/drun/Drun/move.html>
Future myTaskThatMoves() => task(
  (drun) => drun.move('!/example/.env.copy', '!/example/.env.moved')
);

/// Example of using `del` functionality.
///
/// To delete a file or folder (recursively) you can just call
/// `del` with a `path`. If tha path doesnopt not exist it will do nothing.
/// It will log if it deletes anything.
Future myTaskThatDeletes() => task((drun) => drun.del('!/example/.env.copy'));

/// Example of using `searchReplace` functionality.
///
/// To replace text in a file you can use `searchReplaceFile` with a `path`
/// and a list of `patterns` and `replacements`. The modifications will be
/// written back to the same file unless a custom `out` path is provided.
///
/// HINT: If you already have some text in memory you can use
///       `searchReplace` instead.
///
/// see: <https://pub.dev/documentation/drun/latest/drun/Drun/searchReplaceFile.html>
Future myTaskThatSearchesAndReplaces() => task((drun) => drun.searchReplaceFile(
  '!/example/.env',
  [RegExp(r'XYZ=.*')],
  ['XYZ=a-different-value'],
));
```
