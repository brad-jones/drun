import 'dart:mirrors';

import 'package:args/args.dart';
import 'package:recase/recase.dart';
import 'package:stack_trace/stack_trace.dart';

import 'package:drun/src/annotations.dart';
import 'package:drun/src/utils.dart';

/// You may extend this class and populate with static getters for CLI options
/// that are global to your task runner.
///
/// For example:
///
/// ```dart
/// import 'package:drun/drun.dart';
///
/// Future<void> main(List<String> argv) => drun(argv);
///
/// class Options extends GlobalOptions {
///   static String get version {
///     return GlobalOptions.value ?? 'v1.0.0';
///   }
/// }
///
/// void build() {
///   print('building ${Options.version}');
/// }
///
/// void test([bool noBuild = false]) {
///   if (!noBuild) {
///     build();
///   }
///   print('testing ${Options.version}');
/// }
///
/// void publish([bool noTest = false]) {
///   if (!noTest) {
///     test();
///   }
///   print('publishing ${Options.version}');
/// }
///
/// void deploy([bool noPublish = false]) {
///   if (!noPublish) {
///     publish();
///   }
///   print('depoying ${Options.version}');
/// }
/// ```
///
/// Instead of something like:
///
/// ```dart
/// import 'package:drun/drun.dart';
///
/// Future<void> main(List<String> argv) => drun(argv);
///
/// void build([String version = 'v1.0.0']) {
///   print('building ${version}');
/// }
///
/// void test([String version = 'v1.0.0', bool noBuild = false]) {
///   if (!noBuild) {
///     build(version);
///   }
///   print('testing ${version}');
/// }
///
/// void publish([String version = 'v1.0.0', bool noTest = false]) {
///   if (!noTest) {
///     test(version);
///   }
///   print('publishing ${version}');
/// }
///
/// void deploy([String version = 'v1.0.0', bool noPublish = false]) {
///   if (!noPublish) {
///     // whoops I forget to add the version here,
///     // at first the error will go unnoticed because a default is set.
///     publish();
///   }
///   print('deploying ${version}');
/// }
/// ```
///
/// These are obviously contrived examples and neither is complex but when you
/// do have a more complex task runner that has a similar chain you will find
/// you will be passing the same set of parameters between each task function
/// and eventually you will make a mistake.
abstract class GlobalOptions {
  static ArgResults argv;
  static Map<String, String> env;
  static Map<String, MethodMirror> options;

  static dynamic get value {
    var memberName = Trace.current().frames[1].member.split('.')[1];
    var memberMethod = options.values
        .singleWhere((_) => MirrorSystem.getName(_.simpleName) == memberName);

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
