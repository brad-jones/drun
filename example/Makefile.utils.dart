import 'dart:io';

import 'package:drun/drun.dart';

/// To extend the [Drun] instance that is injected into your [task]s simply add
/// extension methods as needed.
///
/// Of course this is just a suggestion and you could just as easily have a
/// collection of normal functions or classes or whatever is required. Nor is
/// the name of the file special in anyway. Remember it's just dart so set
/// things up however they make sense to you and your project.
///
/// The advantage of creating extension methods is that your utilties can take
/// advantage of druns logging and other existing functionality.
extension Utils on Drun {
  void sayHello() {
    log('hello');
  }

  List<String> pingArgs(String target) {
    if (Platform.isWindows) {
      return [target];
    } else {
      return ['-c', '4', target];
    }
  }
}
