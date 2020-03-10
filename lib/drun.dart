import 'dart:io';
import 'dart:mirrors';
import 'package:io/ansi.dart';
import 'package:drun/src/executor.dart';
export 'package:drun/src/annotations.dart';
import 'package:drun/src/write_error.dart';
import 'package:drun/src/discover_tasks.dart';
import 'package:drun/src/build_arg_parser.dart';

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
Future<void> drun(List<String> argv) async {
  var exitCode = 0;
  try {
    var lib = currentMirrorSystem().isolate.rootLibrary;
    var tasks = discoverTasks(lib);
    var parser = buildArgParser(tasks);
    var parsedArgv = parser.parse(argv);
    await executor(lib, tasks, parsedArgv);
  } catch (e, st) {
    await writeError(e, st);
    exitCode = 1;
  } finally {
    stdout.write(resetAll.wrap(''));
    exit(exitCode);
  }
}
