import 'dart:io';
import 'dart:mirrors';
import 'package:args/args.dart';
import 'package:recase/recase.dart';
import 'package:drun/src/write_help.dart';
import 'package:drun/src/annotations.dart';
import 'package:drun/src/type_parser.dart';
import 'package:dotenv/dotenv.dart' as dotenv;

const _version = '0.0.0-semantically-released';

Future<void> executor(
  Map<Uri, LibraryMirror> libs,
  Map<String, MethodMirror> tasks,
  Map<String, MethodMirror> options,
  ArgResults parsedArgv,
  bool hideSubtasks,
) async {
  if (parsedArgv.wasParsed('version')) {
    stdout.writeln(_version);
    return;
  }

  if (parsedArgv.command == null) {
    await writeHelp(tasks, options, parsedArgv, hideSubtasks);
    return;
  }

  var task = tasks[parsedArgv.command.name];

  if (parsedArgv.wasParsed('help')) {
    await writeHelp(
      {parsedArgv.command.name: task},
      options,
      parsedArgv,
      hideSubtasks,
    );
    return;
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
