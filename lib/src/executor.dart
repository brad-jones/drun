import 'dart:io';
import 'dart:mirrors';
import 'package:args/args.dart';
import 'package:recase/recase.dart';
import 'package:drun/src/write_help.dart';
import 'package:drun/src/annotations.dart';
import 'package:drun/src/type_parser.dart';

const _version = '0.0.0-semantically-released';

Future<void> executor(
  LibraryMirror lib,
  Iterable<MethodMirror> tasks,
  ArgResults parsedArgv,
) async {
  if (parsedArgv.wasParsed('version')) {
    stdout.writeln(_version);
    return;
  }

  if (parsedArgv.command == null) {
    await writeHelp(parsedArgv, tasks);
    return;
  }

  var task = tasks.singleWhere(
      (_) => _.simpleName == Symbol(parsedArgv.command.name.camelCase));

  if (parsedArgv.wasParsed('help')) {
    await writeHelp(parsedArgv, [task]);
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
      if (Platform.environment.containsKey(envKey)) {
        return typeParser(
          p.type.reflectedType,
          Platform.environment[envKey],
        );
      }
    }

    if (p.hasDefaultValue) {
      return p.defaultValue.reflectee;
    }

    throw 'The option --${pName} is required!';
  }).toList();

  var result = lib.invoke(task.simpleName, taskParameterValues).reflectee;

  if (result is Future) {
    await result;
  }
}
