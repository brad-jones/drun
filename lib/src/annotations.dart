import 'dart:mirrors';

/// Use to add an abbreviated flag to a task parameter.
///
/// For example:
///
/// ```dart
/// void foo(@Abbr('b') String bar) {
///   print(bar);
/// }
/// ```
///
/// Allows you to provide the value of `bar` like this: `drun foo -b abc`
class Abbr {
  final String value;
  const Abbr(this.value);

  static bool hasMetadata(ParameterMirror p) {
    return fromMetadata(p) != null;
  }

  static Abbr fromMetadata(ParameterMirror p) {
    Abbr v;
    var m = p.metadata
        .singleWhere((_) => _.type.reflectedType == Abbr, orElse: () => null);
    if (m != null) {
      v = m.reflectee as Abbr;
    }
    return v;
  }
}

/// Use to read the value of a task parameter from the environment.
///
/// For example:
///
/// ```dart
/// void foo(@Env('BAR') String bar) {
///   print(bar);
/// }
/// ```
///
/// Allows you to provide the value of `bar` like this: `BAR=abc drun foo`.
///
/// _NOTE: A CLI option will always take precedence over an environment variable._
class Env {
  final String value;
  const Env(this.value);

  static bool hasMetadata(ParameterMirror p) {
    return fromMetadata(p) != null;
  }

  static Env fromMetadata(ParameterMirror p) {
    Env v;
    var m = p.metadata
        .singleWhere((_) => _.type.reflectedType == Env, orElse: () => null);
    if (m != null) {
      v = m.reflectee as Env;
    }
    return v;
  }
}

/// Use to enforce a specfic set of values for a task parameter.
///
/// For example:
///
/// ```dart
/// void foo(@Values(['abc', 'xyz']) String bar) {
///   print(bar);
/// }
/// ```
///
/// These calls are valid:
/// - `drun foo --bar abc`
/// - `drun foo --bar xyz`
///
/// This call is not valid:
/// - `drun foo --bar qwerty`
///
/// _NOTE: If the parameter is of another type,
/// like `int` the values still need to be provided as `String`s._
class Values {
  final List<String> values;
  const Values(this.values);

  static bool hasMetadata(ParameterMirror p) {
    return fromMetadata(p) != null;
  }

  static Values fromMetadata(ParameterMirror p) {
    Values v;
    var m = p.metadata
        .singleWhere((_) => _.type.reflectedType == Values, orElse: () => null);
    if (m != null) {
      v = m.reflectee as Values;
    }
    return v;
  }
}
