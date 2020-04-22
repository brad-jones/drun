import 'package:drun/drun.dart';

// Makefiles can recursively import other makefiles
import './baz/Makefile.dart' as baz;

/// Start off by redirecting your main method to the drun method
Future<void> main(List<String> argv) => drun(argv);

/// Builds the bar project
void build() {
  baz.build('v1.0.0');
  print('building project bar');
}
