import 'package:drun/drun.dart';

/// Start off by redirecting your main method to the drun method
Future<void> main(argv) async => drun(argv);

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
/// The same is true for anything that is imported or exported,
/// regardless of their visibility.
///
/// Only public functions in your "Makefile.dart" will be considered as tasks
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
