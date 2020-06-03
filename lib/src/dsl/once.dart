import 'dart:async';
import 'dart:mirrors';

import 'package:async/async.dart';
import 'package:drun/src/utils.dart';
import 'package:stack_trace/stack_trace.dart';

mixin Once {
  static final _onceTasks = <String, AsyncMemoizer>{};

  /// Given any parameterless function this will only ever execute it once.
  /// On subsequent executions that first result is returned.
  ///
  /// Example usage:
  ///
  /// ```dart
  /// Future foo() => task((drun) => drun.once(() => print('hello')));
  ///
  /// Future bar() => task((drun) async {
  ///   await foo();
  ///   await foo();
  ///   await foo();
  /// });
  /// ```
  ///
  /// Executing `drun bar` would print `hello` only 1 time.
  Future<T> once<T>(FutureOr<T> Function() computation) async {
    /*
      Every time an annoymous function is created in dart lang it is
      considered unique from all other instances of the same function.
      What I wanted to do was something like:

      ```dart
      _onceTasks[computation].runOnce(computation);
      ```

      But unless the calling code looked like:

      ```dart
      var x = () => print('hello');
      Future foo() => task((drun) => drun.once(x));
      ```

      This won't work so we have restorted to reflection to solve the issue.
      A combinition of the reflected function's source code and the location
      that we are called from should be unique enough to use as our key.
    */
    var reflected = reflect(computation) as ClosureMirror;
    var frame = Trace.current().frames[1];
    var key = md5String('${frameKey(frame)}${reflected.function.source}');

    if (!_onceTasks.containsKey(key)) {
      _onceTasks[key] = AsyncMemoizer<T>();
    }

    return _onceTasks[key].runOnce(computation);
  }
}
