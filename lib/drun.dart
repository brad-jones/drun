import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:mirrors';
import 'package:io/ansi.dart';
import 'package:drun/src/run.dart';
import 'package:recase/recase.dart';
import 'package:drun/src/build.dart';
import 'package:path/path.dart' as p;
import 'package:drun/src/reflect.dart';
import 'package:drun/src/executor.dart';
import 'package:ansicolor/ansicolor.dart';
export 'package:drun/src/annotations.dart';
import 'package:drun/src/write_error.dart';
import 'package:drun/src/changed_method.dart';
export 'package:drun/src/changed_method.dart';
import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:drun/src/global_options.dart';
import 'package:stack_trace/stack_trace.dart';
export 'package:drun/src/global_options.dart';
import 'package:drun/src/logging.dart' as logging;
import 'package:mustache_template/mustache_template.dart';

/// The main entry point for any `Makefile.dart`.
///
/// * [argv] A list of strings that represent the raw arguments passed to this
///   task runner on the command line.
///
/// * [dotEnvFilePath] By default we look for a `.env` file relative to the
///   location of `Makefile.dart` and attempt to parse that file with `dotenv`.
///   You can supply a custom path if you wish. In any case, if no such file
///   exists then the `dotenv` parsing is simply skipped.
///
/// * [showSubtasks] If set to false then the generated help text will not
///   output sub tasks. This doesn't stop the sub tasks from being called
///   it just doesn't show the sub task list. This is handy for some larger
///   projects where the sub tasks add too much noise and may cause confusion
///   for other developers working on your project.
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
Future<void> drun(
  List<String> argv, {
  String dotEnvFilePath = '.env',
  bool showSubtasks = false,
  bool logBuffered = false,
  String logBufferedTpl = logging.bufferedTplDefault,
  String logPrefixSeperator = logging.prefixSeperatorDefault,
}) async {
  var exitCode = 0;
  try {
    // If a `.env` file exists alongside out `Makefile.dart` lets parse it
    if (await File(dotEnvFilePath).exists()) {
      dotenv.load(dotEnvFilePath);
    }

    // Set custom global logging options
    // This allows someone to do something like: `drun(argv, logBuffered: true)`
    logging.buffered = logBuffered;
    logging.bufferedTpl = logBufferedTpl;
    logging.prefixSeperator = logPrefixSeperator;

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
    await executor(libs, tasks, options, parsedArgv, showSubtasks);
  } catch (e, st) {
    await writeError(e, st);
    exitCode = 1;
  } finally {
    stdout.write(resetAll.wrap(''));
    exit(exitCode);
  }
}

/// Use this to create a new drun task.
///
/// * [computation] Is an annoymous function, async or not, that runs your logic
///
/// * [runOnce] A guid or otherwise unique string that is used along with
///   `AsyncMemoizer` to only run the task one time for a given execution
///   of drun.
///
/// * [runIfNotFound] A list of glob patterns, if any return zero files the
///   task will execute otherwise it will be a NoOp and return null.
///
/// * [runIfChanged] A list of glob patterns, if any files have changed
///   since the last invocation of drun then the task will execute otherwise
///   it will be a NoOp and return null. This is OR'ed with [runIfNotFound].
///
/// * [runIfChangedMethod] When using [runIfChanged] drun will either compare
///   files with a modfied timestamp (faster) of using a sha256 checksum
///   (more accurate).
///
/// * [logPrefix] A custom log prefix to use for any messages output with [log].
///   By default this will use reflection and use the name of task.
///
/// * [logPrefixSeperator] The string that is used between [logPrefix] and the
///   log message.
///
/// * [logBuffered] If set to true then all logs for this task will be stored
///   in memory until the task is complete and then output all at once in a
///   group with a heading of [logPrefix].
///
/// * [logBufferedTpl] If [logBuffered] is true then this mustache template will
///   be used to output the [logPrefix] as a heading for the group of a buffered
///   logs. If this is set to an empty string or null then no heading will be
///   output.
///
/// Usage example:
///
/// ```dart
/// Future<void> build() => task<void>(() {
///   print('building project...');
/// });
/// ```
///
/// The reason we wrap your task function with this function is to provide a
/// hook for drun to execute other logic regardless of how your task is called.
///
/// Many other task runners have an API like `acmerunner.Run(build)` which is
/// where they hook into your task. Where as with the drun approach we can
/// just call `build()` as a normal function from anywhere and not need to
/// worry about the details of drun.
Future<T> task<T>(
  FutureOr<T> Function() computation, {
  String runOnce,
  List<String> runIfNotFound,
  List<String> runIfChanged,
  ChangedMethod runIfChangedMethod = ChangedMethod.timestamp,
  String logPrefix,
  String logPrefixSeperator,
  bool logBuffered,
  String logBufferedTpl,
}) async {
  // Wrap everything in another function, this allows us to easily apply
  // the `runOnce` functionality to everything.
  FutureOr<T> Function() executor = () async {
    T result;

    // Set some defaults from our global settings
    logBuffered ??= logging.buffered;
    logBufferedTpl ??= logging.bufferedTpl;
    logPrefixSeperator ??= logging.prefixSeperator;

    // This stores the log settings for this task into a global location so
    // that when the `log()` function is used inside the `computation()` it can
    // use these settings if nothing has been passed directly to it.
    var frame = Trace.current().frames[2];
    var fKey = frameKey(frame);
    logPrefix ??= frame.member.paramCase;
    logging.settings[fKey] = logging.Settings(
      logPrefix,
      logPrefixSeperator,
      logBuffered,
    );

    // Here we run the actual `computation()`, if required.
    // Depending on the config supplied sometimes we might not need to run the
    // `computation()` at all and thus return a null result.
    if ((runIfNotFound?.isEmpty ?? true) && (runIfChanged?.isEmpty ?? true)) {
      result = await computation();
    } else {
      var r = await ifNotFound(computation, runIfNotFound);
      if (!r.executed) {
        r = await ifChanged(computation, runIfChanged, runIfChangedMethod);
      } else {
        await saveCurrentState(runIfChanged, runIfChangedMethod);
      }
      result = r.result;
    }

    // After running `computation()` output any buffered logs.
    if (logBuffered) {
      writeLogs(logPrefix, tpl: logBufferedTpl);
    }

    // Clean up any global log settings so we don't end up with a leak
    logging.settings.remove(fKey);

    return result;
  };

  // Only run the task one time, returning the same result for susequent calls
  // with-in a single execution of drun.
  if (runOnce?.isNotEmpty ?? false) {
    return once(executor, key: runOnce);
  }

  return executor();
}

/// A simple logging function that can be used by `Makefile.dart` functions.
///
/// * [message] Is the message you wish to print to console.
///
/// * [prefix] A string that is passed through [logColorize] and prefixed to the
///   [message]. This is optional, using reflection it will default to the name
///   of the task that is doing the logging.
///
/// * [seperator] A string that is inserted between [message] and [prefix].
///
/// * [buffered] If set to true then all the logs for a given [prefix] will be
///   stored in memory until they are written by [writeLogs].
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
void log(
  String message, {
  String prefix,
  String seperator = logging.prefixSeperatorDefault,
  bool buffered,
}) {
  var frames = Trace.current().frames;

  // Check for any global logging settings, set by `task()`
  var taskName = frames[1].member.replaceFirst('.<fn>', '');
  var frame =
      frames.firstWhere((_) => _.member == taskName, orElse: () => null);
  if (frame != null) {
    var k = frameKey(frame);
    if (logging.settings.containsKey(k)) {
      var s = logging.settings[k];
      prefix ??= s.prefix;
      seperator ??= s.prefixSeperator;
      buffered ??= s.buffered;
    }
  }

  // Default to using the name of the function that called us,
  // this was the old behaviour so lets keep it for backwards compatibility.
  prefix ??= frames[1].member.paramCase;

  // Store logs in memory if in buffered mode
  if (buffered ?? false) {
    if (!logging.buffers.containsKey(prefix)) {
      logging.buffers[prefix] = <String>[];
    }
    logging.buffers[prefix].add(message);
    return;
  }

  // Otherwise output the message as soon as it is logged
  stdout.writeln('${logColorize(prefix)}${seperator}${message}');
}

/// Call this to output any buffered logs for a [prefix].
///
/// Using this function directly is considered advanced usage,
/// [task] will automatically call this if needed.
///
/// * [prefix] The key that the list of logs are stored under [logBuffers].
///
/// * [tpl] This mustache template will be used to output the [prefix] as a
///   heading for the group of a buffered logs. If this is set to an empty
///   string or null then no heading will be output.
void writeLogs(
  String prefix, {
  String tpl = logging.bufferedTplDefault,
}) {
  if (logging.buffers.containsKey(prefix)) {
    if (logging.buffers[prefix]?.isNotEmpty ?? false) {
      if (tpl?.isNotEmpty ?? false) {
        stdout.write(
          Template(tpl).renderString({'prefix': prefix}),
        );
      }
      stdout.writeAll(logging.buffers[prefix], '\n');
      if (tpl?.isNotEmpty ?? false) {
        stdout.write('\n\n');
      }
      logging.buffers.remove(prefix);
    }
  }
}

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
  if (!logging.prefixToColor.containsKey(prefix)) {
    var availableColors = <int>[];
    var choosenColors = logging.prefixToColor.values;
    if (choosenColors.length >= logging.colors.length) {
      // We reached the maximum number of available colors so
      // we will just have to reuse a color.
      availableColors = logging.colors;
    } else {
      // Restrict avaliable color to ones we have not used yet
      for (var color in logging.colors) {
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
    logging.prefixToColor[prefix] = choosen;
  }

  return AnsiPen()..xterm(logging.prefixToColor[prefix]);
}
