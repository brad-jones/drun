import 'dart:io';
import 'package:dotenv/dotenv.dart' as dotenv;

Future<void> writeError(dynamic e, StackTrace st) async {
  stderr.writeln('Oops, something went wrong: $e');
  if (dotenv.env.containsKey('DRUN_DEBUG')) {
    stderr.writeln('\n$st');
  }
  await stderr.flush();
}
