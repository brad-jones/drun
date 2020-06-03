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

  static bool hasMetadata(DeclarationMirror p) {
    return fromMetadata(p) != null;
  }

  static Abbr fromMetadata(DeclarationMirror p) {
    Abbr v;
    var m = p.metadata
        .singleWhere((_) => _.type.reflectedType == Abbr, orElse: () => null);
    if (m != null) {
      v = m.reflectee as Abbr;
    }
    return v;
  }
}
