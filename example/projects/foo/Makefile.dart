import 'package:drun/drun.dart';

/// Start off by redirecting your main method to the drun method
Future<void> main(List<String> argv) => drun(argv);

/// Builds the foo project
void build() {
  print('building project foo');
}
