import 'package:drun/drun.dart';

/// Eventually you may find yourself with many task functions that all share
/// a subset of the same parameters and you find yourself having to pass the
/// values between your tasks which can get repetitive fast.
///
/// Instead of this you can define an `Options` class which is a collection of
/// static getters. These getters have similar functionality to task parameters.
/// The difference being that these options will apply globally across the
/// entire CLI the same as the built-in `--help` & `--version` flags.
///
/// This class is 100% static and thus can be defined anywhere with-in your
/// task runner, ie: in a seperate `Makefile.opts.dart` would be totally fine.
/// Then just import this file in any other files you may have.
///
/// Remember this is a short lived task runner not a long running productionalised
/// application and thus things like DI & IoC are not a concern, our primary goal
/// is to be quick and easy not necessarily academically correct.
///
/// Just keep in mind that the [GlobalOptions] environment and argv members will
/// not be filled until the main [drun] function has executed. Which should be
/// totally fine because it is [drun] that calls your task function.
class Options extends GlobalOptions {
  /// At it's most basic a global option can be a static value like this one.
  static String get foo {
    return 'foo';
  }

  /// Of course you may generate a value with whatever logic you like.
  /// You just can't use async/await in such cases you might use the
  /// [waitFor] function.
  static int get bar {
    return DateTime.now().millisecondsSinceEpoch;
  }

  /// The previous examples [foo] and [bar] do not actually take into account
  /// any provided values from the command line or the environment and thus will
  /// never appear in any of the generated help pages.
  ///
  /// However this example does allow the user to overide it's value.
  /// [GlobalOptions.value] is a special getter defined in the parent class
  /// that does some magic with reflection to provide the value of this option
  /// as provided through the command line or environment.
  ///
  /// _This is an example of a required global option._
  @Required()
  static String get baz {
    return GlobalOptions.value;
  }

  /// Want to provide a default value, just check for null
  /// from [GlobalOptions.value].
  ///
  /// _This is an example of an optional option._
  static String get abc {
    return GlobalOptions.value ?? 'abc';
  }

  /// Just like task parameters values can be read from either the environment
  /// or cli. Where the cli value always takes precedence.
  @Env('XYZ')
  static String get xyz {
    return GlobalOptions.value ?? 'xyz';
  }

  /// Abbrivations and Value validation also work as expected.
  @Abbr('f')
  @Values(['a', 'b', 'c'])
  static String get foobar {
    return '${GlobalOptions.value ?? 'a'}-${bar}';
  }
}
