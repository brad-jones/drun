import 'dart:io';
import 'dart:mirrors';
import 'package:io/ansi.dart';
import 'package:drun/src/build.dart';
import 'package:path/path.dart' as p;
import 'package:drun/src/reflect.dart';
import 'package:drun/src/executor.dart';
export 'package:drun/src/annotations.dart';
import 'package:drun/src/write_error.dart';
import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:drun/src/global_options.dart';
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
