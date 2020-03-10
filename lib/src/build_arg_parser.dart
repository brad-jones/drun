import 'dart:mirrors';
import 'package:args/args.dart';
import 'package:recase/recase.dart';
import 'package:drun/src/annotations.dart';

ArgParser buildArgParser(Iterable<MethodMirror> tasks) {
  var parser = ArgParser();
  parser.addFlag('help', abbr: 'h');
  parser.addFlag('version', abbr: 'v');

  for (var task in tasks) {
    var command =
        parser.addCommand(MirrorSystem.getName(task.simpleName).paramCase);

    for (var parameter in task.parameters) {
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
