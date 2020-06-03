import 'dart:mirrors';

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

  static bool hasMetadata(DeclarationMirror p) {
    return fromMetadata(p) != null;
  }

  static Values fromMetadata(DeclarationMirror p) {
    Values v;
    var m = p.metadata
        .singleWhere((_) => _.type.reflectedType == Values, orElse: () => null);
    if (m != null) {
      v = m.reflectee as Values;
    }
    return v;
  }
}
