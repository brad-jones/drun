import 'package:drun/drun.dart';

Future main(List<String> argv) => drun(argv);

/// Builds the foo project
Future build() => task((drun) => drun.log('building project foo'));
