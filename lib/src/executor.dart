import 'dart:io';
import 'dart:mirrors';

import 'package:args/args.dart';
import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:recase/recase.dart';

import 'package:drun/src/annotations.dart';
import 'package:drun/src/dsl/logging.dart';
import 'package:drun/src/utils.dart';
import 'package:drun/src/write_help.dart';

const _version = '0.0.0-semantically-released';

/// This function is called after the [ArgParser] has been built and has been
/// run, parsing the CLI arguments into [ArgResults]. This is what actually
/// invokes your task.
Future<void> executor(
  Map<Uri, LibraryMirror> libs,
  Map<String, MethodMirror> tasks,
  Map<String, MethodMirror> options,
  ArgResults parsedArgv,
  bool showSubtasks,
) async {
  if (parsedArgv.wasParsed('version')) {
    stdout.writeln(_version);
    return;
  }

  if (parsedArgv.wasParsed('show-subtasks') ||
      Platform.environment.containsKey('DRUN_SHOW_SUBTASKS')) {
    showSubtasks = true;
  }

  if (parsedArgv.command == null) {
    await writeHelp(tasks, options, parsedArgv, showSubtasks);
    return;
  }

  var task = tasks[parsedArgv.command.name];

  if (parsedArgv.wasParsed('help')) {
    await writeHelp(
      {parsedArgv.command.name: task},
      options,
      parsedArgv,
      showSubtasks,
    );
    return;
  }

  if (parsedArgv.wasParsed('log-buffered') ||
      Platform.environment.containsKey('DRUN_LOG_BUFFERED')) {
    Logging.buffered = true;
  }

  if (parsedArgv.wasParsed('no-log-colors') ||
      Platform.environment.containsKey('DRUN_NO_LOG_COLORS')) {
    Logging.colors = false;
  }

  if (Platform.environment.containsKey('DRUN_LOG_BUFFERED_TPL')) {
    Logging.bufferedTpl = Platform.environment['DRUN_LOG_BUFFERED_TPL'];
  }

  if (Platform.environment.containsKey('DRUN_LOG_PREFIX_SEPERATOR')) {
    Logging.prefixSeperator = Platform.environment['DRUN_LOG_PREFIX_SEPERATOR'];
  }

  var taskParameterValues = task.parameters.map((p) {
    var pName = MirrorSystem.getName(p.simpleName).paramCase;
    var v = parsedArgv.command[pName];

    if (v != null) {
      return typeParser(p.type.reflectedType, v);
    }

    if (Env.hasMetadata(p)) {
      var envKey = Env.fromMetadata(p).value;
      if (dotenv.env.containsKey(envKey)) {
        return typeParser(
          p.type.reflectedType,
          dotenv.env[envKey],
        );
      }
    }

    if (p.hasDefaultValue) {
      return p.defaultValue.reflectee;
    }

    throw 'The option --${pName} is required!';
  }).toList();

  var result = libs[task.location.sourceUri]
      .invoke(task.simpleName, taskParameterValues)
      .reflectee;

  if (result is Future) {
    await result;
  }
}
