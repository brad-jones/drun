import 'package:drun/drun.dart';
import 'package:path/path.dart' as p;

// Makefiles can recursively import other makefiles
import './baz/Makefile.dart' as baz;

Future main(List<String> argv) => drun(argv);

/// Builds the bar project
Future build() => task((drun) => drun.deps([
      baz.build('v1.0.0'),
    ]).then(
      (_) => drun.log('building project bar'),
    ));

/// For more info see `myTaskThatUsesRealPath` in `./example/Makefile.dart`.
///
/// If this task is executed by running this makefile independently of
/// `./example/Makefile.dart`. Or in other words the working directory
/// is `./example/projects/bar` when running `drun my-task-that-uses-real-path`.
///
/// Then both the log messages will be identical however if this task is
/// executed by the parent makefile _(`./example/Makefile.dart`)_. Or in other
/// words the working directory is `./example` when running
/// `drun my-task-that-uses-real-path`.
///
/// Then the paths will be different hopefully this demonstares the need for
/// the `drun.realpath` method with it's special `!` prefix.
Future myTaskThatUsesRealPath() => task((drun) {
      drun.log(p.canonicalize('../../../.github'));
      drun.log(drun.realpath('!/.github'));
    });
