import 'dart:mirrors';

Iterable<MethodMirror> discoverTasks(LibraryMirror lib) {
  return lib.declarations.values
      .whereType<MethodMirror>()
      .where((v) => v.simpleName != Symbol('main') && !v.isPrivate);
}
