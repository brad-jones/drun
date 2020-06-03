import 'dart:mirrors';

/// Used on global option getters to ensure a value is provided via CLI or
/// environment if annotated.
///
/// For example:
///
/// ```dart
/// class Options extends GlobalOptions {
///   @Required()
///   static String get foo {
///     return GlobalOptions.value;
///   }
/// }
/// ```
///
/// [GlobalOptions.value] will now throw an exception if it would have
/// returned null. We need this annotation because of the way global options
/// are implemented as methods and not method parameters that can be implicitly
/// marked as required by not providing a default value.
class Required {
  final bool value;
  const Required([this.value = true]);

  static bool hasMetadata(DeclarationMirror p) {
    return fromMetadata(p) != null;
  }

  static Required fromMetadata(DeclarationMirror p) {
    Required v;
    var m = p.metadata.singleWhere((_) => _.type.reflectedType == Required,
        orElse: () => null);
    if (m != null) {
      v = m.reflectee as Required;
    }
    return v;
  }
}
