import 'dart:mirrors';

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

  static bool hasMetadata(DeclarationMirror p) {
    return fromMetadata(p) != null;
  }

  static Env fromMetadata(DeclarationMirror p) {
    Env v;
    var m = p.metadata
        .singleWhere((_) => _.type.reflectedType == Env, orElse: () => null);
    if (m != null) {
      v = m.reflectee as Env;
    }
    return v;
  }
}
