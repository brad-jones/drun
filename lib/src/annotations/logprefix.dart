import 'dart:mirrors';

/// Sets a custom log prefix for a task.
///
/// For example:
///
/// ```dart
/// @LogPrefix('custom-prefix')
/// Future foo() => task((drun) => drun.log('hello world'));
/// ```
///
/// Executing `drun foo` outputs `custom-prefix | hello world`
class LogPrefix {
  final String value;
  const LogPrefix(this.value);

  static bool hasMetadata(DeclarationMirror p) {
    return fromMetadata(p) != null;
  }

  static LogPrefix fromMetadata(DeclarationMirror p) {
    LogPrefix v;
    var m = p.metadata.singleWhere((_) => _.type.reflectedType == LogPrefix,
        orElse: () => null);
    if (m != null) {
      v = m.reflectee as LogPrefix;
    }
    return v;
  }
}
