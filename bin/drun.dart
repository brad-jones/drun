import 'dart:io';
import 'package:dexeca/dexeca.dart';
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

  var args = <String>[script, ...argv];

  if (Platform.isWindows) {
    final result = await dexeca(
      'dart',
      args,
      captureOutput: false,
    );
    exit(result.exitCode);
  }

  dexecve('dart', args);

  stderr.writeln('dexecve failed to start dart ${args}');
  exit(1);
}
