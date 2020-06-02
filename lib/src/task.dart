import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:drun/src/utils.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:recase/recase.dart';
import 'package:stack_trace/stack_trace.dart';

import 'package:drun/src/drun_class.dart';
import 'package:drun/src/logging.dart' as logging;

/// Use this to create a new drun task.
///
/// * [computation] Is an annoymous function, async or not, that runs your logic
///   This function accepts a single parameter, an instance of [Drun].
///
/// * [runOnce] A guid or otherwise unique string that is used along with
///   `AsyncMemoizer` to only run the task one time for a given execution
///   of drun.
///
/// * [runIfNotFound] A list of glob patterns, if any return zero files the
///   task will execute otherwise it will be a NoOp and return null.
///
/// * [runIfChanged] A list of glob patterns, if any files have changed
///   since the last invocation of drun then the task will execute otherwise
///   it will be a NoOp and return null. This is OR'ed with [runIfNotFound].
///
/// * [runIfChangedMethod] When using [runIfChanged] drun will either compare
///   files with a modfied timestamp (faster) of using a sha256 checksum
///   (more accurate).
///
/// * [logPrefix] A custom log prefix to use for any messages output with [log].
///   By default this will use reflection and use the name of task.
///
/// * [logPrefixSeperator] The string that is used between [logPrefix] and the
///   log message.
///
/// * [logBuffered] If set to true then all logs for this task will be stored
///   in memory until the task is complete and then output all at once in a
///   group with a heading of [logPrefix].
///
/// * [logBufferedTpl] If [logBuffered] is true then this mustache template will
///   be used to output the [logPrefix] as a heading for the group of a buffered
///   logs. If this is set to an empty string or null then no heading will be
///   output.
///
/// Usage example:
///
/// ```dart
/// Future build() => task((drun) {
///   drun.log('building project...');
/// });
/// ```
///
/// The reason we wrap your task function with this function is to provide a
/// hook for drun to execute other logic regardless of how your task is called.
///
/// Many other task runners have an API like `acmerunner.Run(build)` which is
/// where they hook into your task. Where as with the drun approach we can
/// just call `build()` as a normal function from anywhere and not need to
/// worry about the details of drun.
Future<T> task<T>(
  FutureOr<T> Function(Drun) computation, {
  String runOnce,
  List<String> runIfNotFound,
  List<String> runIfChanged,
  ChangedMethod runIfChangedMethod = ChangedMethod.timestamp,
  String logPrefix,
  String logPrefixSeperator,
  bool logBuffered,
  String logBufferedTpl,
}) async {
  // Wrap everything in another function, this allows us to
  // easily apply the `runOnce` functionality to everything.
  FutureOr<T> Function() executor = () async {
    T result;

    // Create the drun instance.
    // This is an object that is injected into each task's computation function.
    // It provides additonal common functionality such as logging.
    var drun = Drun(
      logging.colorize(logPrefix ?? Trace.current().frames[2].member.paramCase),
      logBuffered ?? logging.buffered,
      logBufferedTpl ?? logging.bufferedTpl,
      logPrefixSeperator ?? logging.prefixSeperator,
    );

    // Here we run the actual `computation()`, if required.
    // Depending on the config supplied sometimes we might not need to run the
    // `computation()` at all and thus return a null result.
    if ((runIfNotFound?.isEmpty ?? true) && (runIfChanged?.isEmpty ?? true)) {
      result = await computation(drun);
    } else {
      var r = await _ifNotFound(computation, runIfNotFound, drun);
      if (!r.executed) {
        r = await _ifChanged(
          computation,
          runIfChanged,
          runIfChangedMethod,
          drun,
        );
      } else {
        await _saveCurrentState(runIfChanged, runIfChangedMethod);
      }
      result = r.result;
    }

    // After running `computation()` output any buffered logs.
    drun.writeBufferedLogs();

    return result;
  };

  // Only run the task one time, returning the same result
  // for susequent calls with-in a single execution of drun.
  if (runOnce?.isNotEmpty ?? false) {
    return _once(executor, runOnce);
  }

  return executor();
}

/// When using [runIfChanged] this functionality will default to using the
/// files [timestamp] for comparison or you can use a [checksum] which will be
/// more accurate but slower.
enum ChangedMethod { checksum, timestamp }

var _onceTasks = <String, AsyncMemoizer>{};

Future<T> _once<T>(FutureOr<T> Function() computation, String key) async {
  if (!_onceTasks.containsKey(key)) {
    _onceTasks[key] = AsyncMemoizer<T>();
  }
  return _onceTasks[key].runOnce(computation);
}

class _RunResult<T> {
  final T result;
  final bool executed;
  const _RunResult(this.result, this.executed);
}

Future<_RunResult<T>> _ifNotFound<T>(
  FutureOr<T> Function(Drun) computation,
  List<String> globs,
  Drun drun,
) async {
  if (globs?.isNotEmpty ?? false) {
    for (var glob in globs) {
      var found = false;
      try {
        await for (var _ in Glob(fixGlobForWindows(glob)).list()) {
          found = true;
          break;
        }
      } on FileSystemException {
        found = false;
      }
      if (!found) {
        return _RunResult(await computation(drun), true);
      }
    }
  }
  return _RunResult(null, false);
}

Future<_RunResult<T>> _ifChanged<T>(
  FutureOr<T> Function(Drun) computation,
  List<String> globs,
  ChangedMethod method,
  Drun drun,
) async {
  if (globs?.isNotEmpty ?? false) {
    var currentStateItems = <String, String>{};
    for (var glob in globs) {
      await for (var f in Glob(fixGlobForWindows(glob)).list()) {
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
      var result = await computation(drun);
      await previousStateFile.writeAsString(currentState);
      return _RunResult(result, true);
    }
  }
  return _RunResult(null, false);
}

Future<void> _saveCurrentState(List<String> globs, ChangedMethod method) async {
  if (globs?.isNotEmpty ?? false) {
    var currentStateItems = <String, String>{};
    for (var glob in globs) {
      await for (var f in Glob(fixGlobForWindows(glob)).list()) {
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
