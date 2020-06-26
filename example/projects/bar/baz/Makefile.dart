import 'package:drun/drun.dart';

Future main(List<String> argv) => drun(argv);

/// Builds the baz project
Future build(String version) =>
    task((drun) => drun.log('building project baz ${version}'));
