import 'dart:mirrors';
import 'package:recase/recase.dart';
import 'package:drun/src/global_options.dart';

Map<Uri, LibraryMirror> reflectLibs(MirrorSystem ms) {
  var libs = <Uri, LibraryMirror>{};

  for (var k in ms.libraries.keys) {
    if (k.isScheme('file') &&
        k.path.contains(RegExp(r'^.*Makefile.*\.dart$'))) {
      libs[k] = ms.libraries[k];
    }
  }

  return libs;
}

Map<String, LibraryMirror> reflectDeps(LibraryMirror makeFile, String prefix) {
  var deps = <String, LibraryMirror>{};
  deps[prefix] = makeFile;

  for (var dep in makeFile.libraryDependencies) {
    if (dep.targetLibrary.location.sourceUri.path.endsWith('Makefile.dart')) {
      if (dep.isImport) {
        deps.addAll(reflectDeps(
          dep.targetLibrary,
          '${prefix}${prefix == '' ? '' : ':'}${MirrorSystem.getName(dep.prefix)}',
        ));
      }
    }
  }

  return deps;
}

Map<String, MethodMirror> reflectTasks(
  Map<Uri, LibraryMirror> libs,
  Map<String, LibraryMirror> deps,
) {
  var tasks = <String, MethodMirror>{};

  for (var e in libs.entries) {
    if (e.key.path.endsWith('Makefile.dart')) {
      for (var task in e.value.declarations.values
          .whereType<MethodMirror>()
          .where((v) => v.simpleName != Symbol('main') && !v.isPrivate)) {
        var prefix = deps.entries
            .singleWhere(
                (_) =>
                    _.value.location.sourceUri ==
                    (task.owner as LibraryMirror).uri,
                orElse: () => null)
            .key;

        tasks['${prefix}${prefix == '' ? '' : ':'}${MirrorSystem.getName(task.simpleName).paramCase}'] =
            task;
      }
    }
  }

  return tasks;
}

Map<String, MethodMirror> reflectOptions(Map<Uri, LibraryMirror> libs) {
  var options = <String, MethodMirror>{};

  ClassMirror optionsClass;
  for (var lib in libs.values) {
    var result = lib.declarations.values
        .whereType<ClassMirror>()
        .where((v) => !v.isPrivate)
        .where((v) => v.isSubclassOf(reflectClass(GlobalOptions)));

    if (result.length == 1) {
      optionsClass = result.first;
    } else if (result.length > 1) {
      throw Exception('can only have a single options class');
    }
  }

  if (optionsClass != null) {
    for (var e in optionsClass.staticMembers.entries) {
      if (e.value.source?.contains('GlobalOptions.value') ?? false) {
        options[MirrorSystem.getName(e.key).paramCase] = e.value;
      }
    }
  }

  return options;
}
