import 'dart:cli';
import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import 'package:drun/src/dsl/realpath.dart';
import 'package:drun/src/utils.dart';

/// When using `changed` functionality it will default to using
/// [ChangedMethod.timestamp] for comparison of files or you can use
/// [ChangedMethod.checksum] which will be more accurate but slower.
enum ChangedMethod { checksum, timestamp }

mixin NotFoundOrChanged on Realpath {
  /// This function will return `false` the moment a glob pattern does not
  /// return any valid results. If all glob patterns return at least a single
  /// valid path then this function will return `true`.
  Future<bool> exists(List<String> globs) async {
    for (var glob in globs) {
      var found = false;
      try {
        await for (var _ in Glob(fixGlobForWindows(realpath(glob))).list()) {
          found = true;
          break;
        }
      } on FileSystemException {
        found = false;
      }
      if (!found) {
        return false;
      }
    }
    return true;
  }

  /// A synchronous version of [exists].
  bool existsSync(List<String> globs) {
    return waitFor(exists(globs));
  }

  File _stateFileName(List<String> globs, ChangedMethod method) {
    var hash = md5String('${globs.join()}${method.toString()}');
    return File(p.join(
      Directory.systemTemp.path,
      'drun-1501de6e-58c9-4f86-b61c-cd310195c861',
      'run-if-changed-state',
      '${hash}',
    ));
  }

  /// This function will return `true` if any files found with [globs] have
  /// changed since the last execution of this method, otherwise `false`
  /// will be returned.
  Future<bool> changed(
    List<String> globs, {
    ChangedMethod method = ChangedMethod.timestamp,
  }) async {
    var stateFile = _stateFileName(globs, method);
    var currentState = await _getCurrentState(globs, method);

    String previousState;
    if (await stateFile.exists()) {
      previousState = await stateFile.readAsString();
    } else {
      await stateFile.create(recursive: true);
    }

    var result = currentState != previousState;
    if (result) {
      await (await stateFile.create(recursive: true))
          .writeAsString(currentState);
    }

    return result;
  }

  /// A synchronous version of [changed].
  bool changedSync(
    List<String> globs, {
    ChangedMethod method = ChangedMethod.timestamp,
  }) {
    return waitFor(changed(globs, method: method));
  }

  /// This method combines both [exists] & [changed] into a single call.
  ///
  /// If [existGlobs] returns no matches then this function will save the
  /// current state of the [changedGlobs] and return `true`.
  ///
  /// Otherwise [changed] is called and the result returned.
  Future<bool> notFoundOrChanged(
    List<String> existGlobs,
    List<String> changedGlobs, {
    ChangedMethod method = ChangedMethod.timestamp,
  }) async {
    if (!await exists(existGlobs)) {
      await _saveCurrentState(changedGlobs, method);
      return true;
    }
    return await changed(changedGlobs, method: method);
  }

  /// A synchronous version of [notFoundOrChangedSync].
  bool notFoundOrChangedSync(
    List<String> existGlobs,
    List<String> changedGlobs, {
    ChangedMethod method = ChangedMethod.timestamp,
  }) {
    return waitFor(notFoundOrChanged(existGlobs, changedGlobs, method: method));
  }

  Future<String> _getCurrentState(
    List<String> globs,
    ChangedMethod method,
  ) async {
    var currentStateItems = <String, String>{};
    for (var glob in globs) {
      await for (var f in Glob(fixGlobForWindows(realpath(glob))).list()) {
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

    return sha256String(currentStateBuffer.toString());
  }

  Future<void> _saveCurrentState(
    List<String> globs,
    ChangedMethod method,
  ) async {
    var stateFile = _stateFileName(globs, method);
    var currentState = await _getCurrentState(globs, method);
    await (await stateFile.create(recursive: true)).writeAsString(currentState);
  }
}
