import 'dart:mirrors';
import 'package:args/args.dart';
import 'package:recase/recase.dart';
import 'package:drun/src/annotations.dart';

ArgParser buildArgParser(
  Map<String, MethodMirror> tasks,
  Map<String, MethodMirror> options,
) {
  var parser = ArgParser();
  parser.addFlag('help', abbr: 'h');
  parser.addFlag('version', abbr: 'v');
  parser.addFlag('show-subtasks');
  parser.addFlag('log-buffered');

  for (var e in options.entries) {
    var abbrValue =
        Abbr.hasMetadata(e.value) ? Abbr.fromMetadata(e.value).value : null;

    if (e.value.returnType.reflectedType == bool) {
      parser.addFlag(e.key, abbr: abbrValue, negatable: false);
      continue;
    }

    if (e.value.returnType.reflectedType.toString().startsWith('List<')) {
      parser.addMultiOption(e.key, abbr: abbrValue);
    } else {
      var allowed;
      if (Values.hasMetadata(e.value)) {
        allowed = Values.fromMetadata(e.value).values;
      }
      parser.addOption(e.key, abbr: abbrValue, allowed: allowed);
    }
  }

  for (var e in tasks.entries) {
    var command = parser.addCommand(e.key);

    for (var parameter in e.value.parameters) {
      var optName = MirrorSystem.getName(parameter.simpleName).paramCase;

      var abbrValue = Abbr.hasMetadata(parameter)
          ? Abbr.fromMetadata(parameter).value
          : null;

      if (parameter.type.reflectedType == bool) {
        command.addFlag(optName, abbr: abbrValue, negatable: false);
        continue;
      }

      if (parameter.type.reflectedType.toString().startsWith('List<')) {
        command.addMultiOption(optName, abbr: abbrValue);
      } else {
        var allowed;
        if (Values.hasMetadata(parameter)) {
          allowed = Values.fromMetadata(parameter).values;
        }

        command.addOption(optName, abbr: abbrValue, allowed: allowed);
      }
    }
  }

  return parser;
}
