import 'dart:async';
import 'dart:io';
import 'dart:mirrors';

import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;

import 'package:drun/src/build_arg_parser.dart';
import 'package:drun/src/executor.dart';
import 'package:drun/src/global_options.dart';
import 'package:drun/src/logging.dart' as logging;

export 'package:drun/src/annotations.dart';
export 'package:drun/src/drun_class.dart';
export 'package:drun/src/global_options.dart';
export 'package:drun/src/task.dart';
import 'package:drun/src/reflect.dart';

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
  // Exit codes are very important as they are usally used in CI/CD pipelines
  // that rely on programs to communicate their exit status correctly in order
  // to stop or continue the pipeline. Here we assume that everything worked ok
  // unless we catch an exception and then set this to `1`.
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
    // Something failed so make sure we communicate that to who ever called us
    exitCode = 1;

    // Output any errors, optionally outputing the stack trace
    stderr.writeln('Oops, something went wrong: $e');
    if (dotenv.env.containsKey('DRUN_DEBUG')) {
      stderr.writeln('\n$st');
    }
    await stderr.flush();
  } finally {
    // Reset the terminal, this should leave you with a
    // useable terminal even if some task exited uncleanly
    // after setting custom terminal options.
    stdout.write(resetAll.wrap(''));

    // Ensure we exit with an appropriate exit code.
    exit(exitCode);
  }
}
