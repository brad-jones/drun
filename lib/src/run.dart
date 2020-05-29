import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:mirrors';
import 'package:glob/glob.dart';
import 'package:async/async.dart';
import 'package:drun/src/hash.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:drun/src/changed_method.dart';

var _onceTasks = <String, AsyncMemoizer>{};

Future<T> once<T>(FutureOr<T> Function() computation, {String key}) async {
  /*
    We have to resort to reflection because in dartlang everytime a closure
    is created it is seen as different object. This could be resolved by
    writing something like:

    ```dart
      var _foo = () async { print('foo did some work'); }
      Future<void> foo() => runOnce<void>(_foo);
    ```

    But that is super ugly.
  */
  if (key == null) {
    var reflected = reflect(computation) as ClosureMirror;
    key = md5.convert(utf8.encode(reflected.function.source)).toString();
  }
  if (!_onceTasks.containsKey(key)) {
    _onceTasks[key] = AsyncMemoizer<T>();
  }
  return _onceTasks[key].runOnce(computation);
}

class RunResult<T> {
  final T result;
  final bool executed;
  const RunResult(this.result, this.executed);
}

Future<RunResult<T>> ifNotFound<T>(
  FutureOr<T> Function() computation,
  List<String> globs,
) async {
  if (globs?.isNotEmpty ?? false) {
    for (var glob in globs) {
      var found = false;
      try {
        await for (var _ in Glob(_fixGlobForWindows(glob)).list()) {
          found = true;
          break;
        }
      } on FileSystemException {
        found = false;
      }
      if (!found) {
        return RunResult(await computation(), true);
      }
    }
  }
  return RunResult(null, false);
}

Future<RunResult<T>> ifChanged<T>(
  FutureOr<T> Function() computation,
  List<String> globs,
  ChangedMethod method,
) async {
  if (globs?.isNotEmpty ?? false) {
    var currentStateItems = <String, String>{};
    for (var glob in globs) {
      await for (var f in Glob(_fixGlobForWindows(glob)).list()) {
        String value;
        if (method == ChangedMethod.timestamp) {
          value = (await f.stat()).modified.microsecondsSinceEpoch.toString();
        } else {
          value = await sha256File(f.path).toString();
        }
        currentStateItems[p.canonicalize(f.path)] = value;
      }
    }

    var currentStateBuffer = StringBuffer();
    for (var k in currentStateItems.keys.toList()..sort()) {
      currentStateBuffer.write(k);
      currentStateBuffer.write(currentStateItems[k]);
    }

    var currentState = sha256String(currentStateBuffer.toString());

    String previousState;
    var previousStateFile =
        await File(p.absolute('.drun_tool', 'run-if-changed-state'));
    if (await previousStateFile.exists()) {
      previousState = await previousStateFile.readAsString();
    } else {
      await previousStateFile.create(recursive: true);
    }

    if (currentState != previousState) {
      var result = await computation();
      await previousStateFile.writeAsString(currentState);
      return RunResult(result, true);
    }
  }
  return RunResult(null, false);
}

Future<void> saveCurrentState(List<String> globs, ChangedMethod method) async {
  if (globs?.isNotEmpty ?? false) {
    var currentStateItems = <String, String>{};
    for (var glob in globs) {
      await for (var f in Glob(_fixGlobForWindows(glob)).list()) {
        String value;
        if (method == ChangedMethod.timestamp) {
          value = (await f.stat()).modified.microsecondsSinceEpoch.toString();
        } else {
          value = await sha256File(f.path).toString();
        }
        currentStateItems[p.canonicalize(f.path)] = value;
      }
    }

    var currentStateBuffer = StringBuffer();
    for (var k in currentStateItems.keys.toList()..sort()) {
      currentStateBuffer.write(k);
      currentStateBuffer.write(currentStateItems[k]);
    }

    var currentState = sha256String(currentStateBuffer.toString());
    await (await File(p.absolute('.drun_tool', 'run-if-changed-state'))
            .create(recursive: true))
        .writeAsString(currentState);
  }
}

String _fixGlobForWindows(String glob) {
  return glob.replaceAll('\\', '/');
}
