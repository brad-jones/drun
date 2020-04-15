import 'dart:io';
import 'package:dexecve/dexecve.dart';

const _version = '0.0.0-semantically-released';

Future main(List<String> argv) async {
  final script = 'Makefile.dart';
  final file = File(script);

  if (!await file.exists()) {
    if (argv.contains('--version') || argv.contains('-v')) {
      stdout.writeln(_version);
      exit(0);
    }
    stderr.writeln(
      "Error: expected to find '${script}' relative to the current directory.",
    );
    exit(1);
  }

  dexecve('dart', [script, ...argv]);

  stderr.writeln('this is a bug, dexecve failed us');
  stderr.writeln('you could try `dart ${script} ${argv.join(' ')}`');
  exit(1);
}
