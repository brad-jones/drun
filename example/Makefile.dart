import 'package:drun/drun.dart';

// Global options can be defined in another file or inline anywhere in your makefile
import './Makefile.opts.dart';

// Other makefiles can be imported and their tasks will be prefixed with the import prefix.
import './projects/foo/Makefile.dart' as foo;
import './projects/bar/Makefile.dart' as bar;

/// Start off by redirecting your main method to the drun method
Future<void> main(List<String> argv) => drun(argv);

/// Then just create functions that can be called via the command line
/// call me like: `drun my-task`
///
/// HINT: docblocks are used to generate help text on the command line.
/// try `drun my-task --help`
void myTask() {
  print('Mello World');
}

/// Both sync and async functions are supported
/// call me like: `drun my-async-task`
Future<void> myAsyncTask() async {
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

/// Tasks can call other tasks just like any other function call.
void myTaskThatCallsAnother() {
  foo.build();
}

/// An example of consuming global options.
void myTaskWithGlobalOptions() {
  print(Options.foo);
  print(Options.bar);
  print(Options.baz);
  print(Options.abc);
  print(Options.xyz);
  print(Options.foobar);
}

/// An example of using drun's logging
Future<void> myTaskThatLogs() async {
  await Future.wait([
    myTaskThatLogsFoo(),
    myTaskThatLogsBar(),
    myTaskThatLogsBaz(),
  ]);
}

Future<void> myTaskThatLogsFoo() async {
  log('i did some work');
}

Future<void> myTaskThatLogsBar() async {
  log('i did some work');
}

Future<void> myTaskThatLogsBaz() async {
  log('i did some work', prefix: 'custom-prefix');
}

/// Example of using the `runOnce` function.
void runsOnceExample() {
  myTaskThatRunsOnce();
  myTaskThatRunsOnce();
  myTaskThatRunsOnce();
}

void myTaskThatRunsOnce() => runOnce<void>(() {
      print('If you see me more than once something we wrong');
    });

/// Example of using the `runOnce` function.
Future<void> runsOnceAsyncExample() async {
  await myTaskThatRunsOnce();
  await myTaskThatRunsOnce();
  await myTaskThatRunsOnce();
}

Future<void> myTaskThatRunsOnceAsync() => runOnce<void>(() async {
      print('If you see me more than once something we wrong');
    });
