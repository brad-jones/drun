import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:mirrors';
import 'dart:convert';
import 'package:io/ansi.dart';
import 'package:glob/glob.dart';
import 'package:async/async.dart';
import 'package:recase/recase.dart';
import 'package:crypto/crypto.dart';
import 'package:drun/src/build.dart';
import 'package:path/path.dart' as p;
import 'package:convert/convert.dart';
import 'package:drun/src/reflect.dart';
import 'package:drun/src/executor.dart';
import 'package:ansicolor/ansicolor.dart';
export 'package:drun/src/annotations.dart';
import 'package:drun/src/write_error.dart';
import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:drun/src/global_options.dart';
import 'package:stack_trace/stack_trace.dart';
export 'package:drun/src/global_options.dart';

/// The main entry point for any `Makefile.dart`.
///
/// Usage example:
///
/// ```dart
/// import 'package:drun/drun.dart';
///
/// Future<void> main(argv) async => drun(argv);
///
/// // your task functions go here
/// ```
Future<void> drun(List<String> argv, {String dotEnvFilePath = '.env'}) async {
  var exitCode = 0;
  try {
    // If a `.env` file exists alongside out `Makefile.dart` lets parse it
    if (await File(dotEnvFilePath).exists()) {
      dotenv.load(dotEnvFilePath);
    }

    // Use reflection to discover the structure of the task runner
    var ms = currentMirrorSystem();
    var libs = reflectLibs(ms);
    var rootMakeFile = libs.entries
        .singleWhere((_) =>
            p.normalize(_.key.path).replaceFirst('\\', '') ==
            p.normalize('${Directory.current.path}/Makefile.dart'))
        .value;
    var deps = reflectDeps(rootMakeFile, '');
    var tasks = reflectTasks(libs, deps);
    var options = reflectOptions(libs);

    // Build the cli app
    var parser = buildArgParser(tasks, options);
    var parsedArgv = parser.parse(argv);
    GlobalOptions.argv = parsedArgv;
    GlobalOptions.env = dotenv.env;
    GlobalOptions.options = options;

    // Finally execute the app
    await executor(libs, tasks, options, parsedArgv);
  } catch (e, st) {
    await writeError(e, st);
    exitCode = 1;
  } finally {
    stdout.write(resetAll.wrap(''));
    exit(exitCode);
  }
}

/// A simple logging function that can be used by `Makefile.dart` functions.
///
/// * [message] Is the message you wish to print to console.
///
/// * [prefix] A string that is passed through [logColorize] and prefixed to the
///   [message]. This is optional, it will default to the name of the function
///   that called us.
///
/// * [seperator] A string that is inserted between [message] and [prefix].
///
/// For example:
///
/// ```dart
/// import 'package:drun/drun.dart';
///
/// Future<void> main(argv) async => drun(argv);
///
/// Future<void> fooBar() async {
///   await Future.wait([
///     foo(),
///     bar(),
///   ]);
/// }
///
/// Future<void> foo() async {
///   log('did some work');
/// }
///
/// Future<void> bar() async {
///   log('did some work');
/// }
/// ```
///
/// Executing `drun foo-bar` would output something like:
///
/// ```
/// foo | did some work
/// bar | did some work
/// ```
///
/// Due to use of [logColorize] `foo` & `bar` in the above output will be
/// different colors. This allows one to create output similar to tools like
/// `docker-compose`.
void log(String message, {String prefix, String seperator = ' | '}) {
  prefix ??= Trace.current().frames[1].member.paramCase;
  stdout.writeln('${logColorize(prefix)}${seperator}${message}');
}

// Restrict avaliable colors to 16 bit to ensure best compatibility
// 256 bit terminal colors are nice but without careful choice of colors I find
// that more often than not you get output that is hard to read, sometimes it's
// pretty hard to tell the difference between a darker and lighter color.
var _allColors = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];

// Keep a map of color choices so we don't choose the same, at least until we
// have choosen all available colors.
var _prefixToColor = <String, int>{};

/// Given a [prefix] this function will return that prefix colored with an
/// [AnsiPen] choosen by [logPen]. If [message] is provided then the message
/// will be the string that is colored in the prefix's color instead of the
/// prefix it's self.
///
/// This function is provided for cases where you want to output your own
/// custom logs using some other mechanism instead of [log] but still wish to
/// retain the correct prefix color.
String logColorize(String prefix, {String message}) {
  return logPen(prefix).write(message ?? prefix);
}

/// For a given [prefix] this will return a random [AnsiPen] that can be used
/// to colorize text.
///
/// This function is provided for advanced usage cases where you wish to
/// directly use an [AnsiPen] instance. Please refer to either [log] or
/// [logColorize] for normal usage.
AnsiPen logPen(String prefix) {
  if (!_prefixToColor.containsKey(prefix)) {
    var availableColors = <int>[];
    var choosenColors = _prefixToColor.values;
    if (choosenColors.length >= _allColors.length) {
      // We reached the maximum number of available colors so
      // we will just have to reuse a color.
      availableColors = _allColors;
    } else {
      // Restrict avaliable color to ones we have not used yet
      for (var color in _allColors) {
        if (!choosenColors.contains(color)) {
          availableColors.add(color);
        }
      }
    }

    // Choose a new color
    int choosen;
    if (availableColors.length == 1) {
      choosen = availableColors[0];
    } else {
      choosen = availableColors[Random().nextInt(availableColors.length)];
    }
    _prefixToColor[prefix] = choosen;
  }

  return AnsiPen()..xterm(_prefixToColor[prefix]);
}

/// Will only execute [computation] once for a single execution of `drun`.
/// This is very handy for constructing complex dependant build chains.
///
/// For example:
///
/// ```dart
/// import 'package:drun/drun.dart';
///
/// Future<void> main(List<String> argv) => drun(argv);
///
/// Future<void> foo() => runOnce<void>(() async {
///   print('foo did some work');
/// });
///
/// Future<void> bar() async {
///   await foo();
///   print('bar did some work');
/// }
///
/// Future<void> baz() async {
///   await foo();
///   print('baz did some work');
/// }
///
/// Future<void> build() async {
///   await bar();
///   await baz();
/// }
/// ```
///
/// Executing `drun build` will output:
///
/// ```
/// foo did some work
/// bar did some work
/// baz did some work
/// ```
Future<T> runOnce<T>(FutureOr<T> Function() computation) async {
  /*
    We have to resort to reflection because in dartlang everytime a closure
    is created it is seen as different object. This could be resolved by
    writing something like:

    ```dart
      var _foo = () async { print('foo did some work'); }
      Future<void> foo() => runOnce<void>(_foo);
    ```

    But that is super ugly.
  */
  var reflected = reflect(computation) as ClosureMirror;
  var key = md5.convert(utf8.encode(reflected.function.source));
  if (!_onceTasks.containsKey(key)) {
    _onceTasks[key] = AsyncMemoizer<T>();
  }
  return _onceTasks[key].runOnce(computation);
}

var _onceTasks = <Digest, AsyncMemoizer>{};

/// Will only execute [computation] if one of the [globs] doesn't match anything
///
/// For example:
///
/// ```dart
/// import 'package:drun/drun.dart';
///
/// Future<void> main(List<String> argv) => drun(argv);
///
/// Future<void> build() => runIfNotFound<void>(() async {
///   print('building ./bin/foo');
/// }, ['./bin/foo']);
/// ```
Future<T> runIfNotFound<T>(
  FutureOr<T> Function() computation,
  List<String> globs,
) async {
  for (var glob in globs) {
    var found = false;
    try {
      await for (var _ in Glob(glob).list()) {
        found = true;
        break;
      }
    } on FileSystemException {
      found = false;
    }
    if (!found) {
      return await computation();
    }
  }
  return null;
}

/// The way in which [runIfChanged] will check if files have changed
enum ChangedMethod { checksum, timestamp }

/// Will only execute [computation] if one of the [globs] has changed.
///
/// You have the option to change [method] to checksum if comparing modified
/// timestamps is not reliable enough.
///
/// For example:
///
/// ```dart
/// import 'package:drun/drun.dart';
///
/// Future<void> main(List<String> argv) => drun(argv);
///
/// Future<void> build() => runIfChanged<void>(() async {
///   print('building ./bin/foo');
/// }, ['./bin/foo']);
/// ```
///
/// You might also like to add `.drun_tool` to your `.gitignore` as this is
/// where information about the state of the files will be kept.
Future<T> runIfChanged<T>(
  FutureOr<T> Function() computation,
  List<String> globs, {
  ChangedMethod method = ChangedMethod.timestamp,
}) async {
  var currentStateItems = <String, String>{};
  for (var glob in globs) {
    await for (var f in Glob(glob).list()) {
      String value;
      if (method == ChangedMethod.timestamp) {
        value = (await f.stat()).modified.microsecondsSinceEpoch.toString();
      } else {
        value = await _sha256File(f.path).toString();
      }
      currentStateItems[p.canonicalize(f.path)] = value;
    }
  }

  var currentStateBuffer = StringBuffer();
  for (var k in currentStateItems.keys.toList()..sort()) {
    currentStateBuffer.write(k);
    currentStateBuffer.write(currentStateItems[k]);
  }

  var currentState = _sha256String(currentStateBuffer.toString());

  String previousState;
  var previousStateFile =
      await File(p.absolute('.drun_tool', 'run-if-changed-state'));
  if (await previousStateFile.exists()) {
    previousState = await previousStateFile.readAsString();
  } else {
    await previousStateFile.create(recursive: true);
  }

  if (currentState != previousState) {
    var result = await computation();
    await previousStateFile.writeAsString(currentState);
    return result;
  }

  return null;
}

String _sha256String(String value) {
  return sha256.convert(utf8.encode(value)).toString();
}

Future<Digest> _sha256File(String path) async {
  var output = AccumulatorSink<Digest>();
  var input = sha256.startChunkedConversion(output);
  await for (var chunk in File(path).openRead()) {
    input.add(chunk);
  }
  input.close();
  return output.events.single;
}
