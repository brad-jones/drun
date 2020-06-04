import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:recase/recase.dart';
import 'package:stack_trace/stack_trace.dart';

import 'package:drun/src/global_options.dart';

String fixGlobForWindows(String glob) {
  return glob.replaceAll('\\', '/');
}

String frameKey(Frame f) {
  return '${f.column}${f.line}${f.member}${f.uri}';
}

String md5String(String value) {
  return md5.convert(utf8.encode(value)).toString();
}

String sha256String(String value) {
  return sha256.convert(utf8.encode(value)).toString();
}

Future<Digest> sha256File(String path) async {
  var output = AccumulatorSink<Digest>();
  var input = sha256.startChunkedConversion(output);
  await for (var chunk in File(path).openRead()) {
    input.add(chunk);
  }
  input.close();
  return output.events.single;
}

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

Map<String, MethodMirror> _tasks;
Map<String, MethodMirror> _allTasks;
Map<String, MethodMirror> reflectTasks(
  Map<Uri, LibraryMirror> libs,
  Map<String, LibraryMirror> deps,
) {
  if (_tasks == null) {
    _allTasks = <String, MethodMirror>{};

    var sortedDeps = deps.entries.toList();
    sortedDeps.sort((a, b) {
      if (a.key.split(':').length > b.key.split(':').length) {
        return 1;
      }
      return 0;
    });

    for (var e in libs.entries) {
      if (e.key.path.endsWith('Makefile.dart')) {
        for (var task in e.value.declarations.values
            .whereType<MethodMirror>()
            .where((v) => v.simpleName != Symbol('main'))) {
          var prefix = sortedDeps
              .firstWhere(
                  (_) =>
                      _.value.location.sourceUri ==
                      (task.owner as LibraryMirror).uri,
                  orElse: () => null)
              .key;

          _allTasks[
                  '${prefix}${prefix == '' ? '' : ':'}${MirrorSystem.getName(task.simpleName).paramCase}'] =
              task;
        }
      }
    }

    _tasks = <String, MethodMirror>{};
    for (var e in _allTasks.entries.where((e) => !e.value.isPrivate)) {
      _tasks[e.key] = e.value;
    }
  }

  return _tasks;
}

MapEntry<String, MethodMirror> reflectTask(Frame frame) {
  for (var e in _allTasks.entries) {
    if (MirrorSystem.getName(e.value.simpleName) == frame.member) {
      if ((e.value.owner as LibraryMirror).uri == frame.uri) {
        return e;
      }
    }
  }
  return null;
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

dynamic typeParser(Type reflectedType, dynamic v) {
  switch (reflectedType) {
    case int:
      return int.parse(v);
    case double:
      return double.parse(v);
    default:
      if (reflectedType.toString().startsWith('List<')) {
        switch (reflectType(reflectedType).typeArguments[0].reflectedType) {
          case int:
            var list = <int>[];
            for (var value in (v as List<String>)) {
              list.add(int.parse(value));
            }
            return list;
          case double:
            var list = <double>[];
            for (var value in (v as List<String>)) {
              list.add(double.parse(value));
            }
            return list;
        }
      }
      return v;
  }
}
