import 'dart:io';

const _version = '0.0.0-semantically-released';

Future main(List<String> args) async {
  final script = 'Makefile.dart';
  final file = File(script);

  if (!await file.exists()) {
    if (args.contains('--version') || args.contains('-v')) {
      stdout.writeln(_version);
      exit(0);
    }
    stderr.writeln(
      "Error: expected to find '${script}' relative to the current directory.",
    );
    exit(1);
  }

  final proc = await Process.start('dart', <String>[script, ...args]);
  await stdout.addStream(proc.stdout);
  await stderr.addStream(proc.stderr);
  exit(await proc.exitCode);
}
