import 'dart:mirrors';
import 'package:args/args.dart';
import 'package:drun/src/utils.dart';
import 'package:recase/recase.dart';
import 'package:drun/src/annotations.dart';
import 'package:stack_trace/stack_trace.dart';

mixin GlobalOptions {
  ArgResults argv;
  Map<String, String> env;
  Map<String, MethodMirror> options;

  dynamic get optionValue {
    var memberName = Trace.current().frames[1].member.split('.')[1];
    var memberMethod = options.values.singleWhere(
        (_) => MirrorSystem.getName(_.simpleName) == 'Options.${memberName}');

    var argName = memberName.paramCase;
    var v = argv[argName];
    if (v != null) {
      return typeParser(memberMethod.returnType.reflectedType, v);
    }

    if (Env.hasMetadata(memberMethod)) {
      var envKey = Env.fromMetadata(memberMethod).value;
      if (env.containsKey(envKey)) {
        return typeParser(
          memberMethod.returnType.reflectedType,
          env[envKey],
        );
      }
    }

    if (Required.hasMetadata(memberMethod)) {
      if (Required.fromMetadata(memberMethod).value) {
        throw 'The option --${argName} is required!';
      }
    }

    return null;
  }
}
