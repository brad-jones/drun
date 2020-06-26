import 'package:drun/drun.dart';

/// Eventually you may find yourself with many task functions that all share
/// a subset of the same parameters and you find yourself having to pass the
/// values between your tasks which can get repetitive fast.
///
/// Instead of this you can define global `Options` by extending the built-in
/// [Drun] class with additional property getters in the same way that you can
/// extend the DSL with additional methods.
///
/// These getters have similar functionality to task parameters. The difference
/// being that these options will apply globally across the entire CLI, the same
/// as the built-in `--help` & `--version` flags.
///
/// NOTE: You must use `extension Options on Drun`, `extension Foo on Drun`
///       will not work.
extension Options on Drun {
  /// At it's most basic a global option can be a static value like this one.
  String get foo {
    return 'foo';
  }

  /// Of course you may generate a value with whatever logic you like.
  int get bar {
    return DateTime.now().millisecondsSinceEpoch;
  }

  /// The previous examples [foo] and [bar] do not actually take into account
  /// any provided values from the command line or the environment and thus will
  /// never appear in any of the generated help pages.
  ///
  /// However this example does allow the user to overide it's value.
  /// [optionValue] is a special getter defined in the parent class [Drun]
  /// that does some magic with reflection to provide the value of this
  /// option as provided through the command line or environment.
  ///
  /// _This is an example of a required global option._
  @Required()
  String get baz {
    return optionValue;
  }

  /// Want to provide a default value, just check for null from [this.value].
  ///
  /// _This is an example of a global optional option._
  String get abc {
    return optionValue ?? 'abc';
  }

  /// Just like task parameters values can be read from either the environment
  /// or cli. Where the cli value always takes precedence.
  @Env('XYZ')
  String get xyz {
    return optionValue ?? 'xyz';
  }

  /// Abbrivations and Value validation also work as expected.
  @Abbr('f')
  @Values(['a', 'b', 'c'])
  String get foobar {
    return '${optionValue ?? 'a'}-${bar}';
  }
}
