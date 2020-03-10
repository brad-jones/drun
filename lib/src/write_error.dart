import 'dart:io';

Future<void> writeError(dynamic e, StackTrace st) async {
  stderr.writeln('Oops, something went wrong: $e');
  if (Platform.environment.containsKey('DRUN_DEBUG')) {
    stderr.writeln('\n$st');
  }
  await stderr.flush();
}
