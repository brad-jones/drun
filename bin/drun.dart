import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart' as analyzer;
import 'package:analyzer/dart/ast/ast.dart';
import 'package:archive/archive_io.dart';
import 'package:archive/archive.dart';
import 'package:console/console.dart';
import 'package:dexeca/dexeca.dart';
import 'package:dexeca/look_path.dart';
import 'package:dexecve/dexecve.dart';
import 'package:http/http.dart' as http;
import 'package:json2yaml/json2yaml.dart';
import 'package:path/path.dart' as p;
import 'package:pubspec_yaml/pubspec_yaml.dart';
import 'package:queries/collections.dart';
import 'package:recase/recase.dart';

const _DEFAULT_SCRIPT = 'Makefile.dart';
const _VERSION = '0.0.0-semantically-released';
const _HELP_TXT = '''
Usage: drun [options] [/path/to/dart/script] [script arguments]

Options:
  --help, -h: Shows this help message, not the generated help txt from the
              drun library.

  --version, -v: Shows the version of this binary, which is not necessarily the
                 same version as the drun library.

> These options only work when no script is found, if a valid dart script is
> found all additional arguments are passed to that script. Which is why you
> might see different results based on the existence of a valid script.

Drun runs dart scripts, given a path to any dartlang script it will attempt
execute that script using dart. In the event no script is given it defaults
to executing `./Makefile.dart`.

Before executing any script drun will do the following additional actions:

  - Having installed the dart2native version of this binary, it's possible you
    do not actually have dart installed so drun will install it for you if it
    can not find the dart binary.

  - If a pubspec.yaml can not be found the script and any other imported scripts
    will be parsed and a pubspec.yaml file will be generated for you based on
    all imported packages. The latest stable version of each package will be used.

  - Once a pubspec.yaml file exists itt will also execute `pub get` to ensure
    all dependencies are installed. Drun will only do this if it detects a
    `pubspec.yaml` file in the same directory as the script it is executing and
    the `.packages` file does not exist.

To get additional debugging information from drun you can set the environment
variable `DRUN_DEBUG` to any non empty value. Then additonal logging and stack
traces will be printed.

Finally of course if you don't want any of this functionality simply execute
your dart script directly with dart, even drun Makefile.dart scripts can easily
be executed directly with dart for a more pure (faster) experience.
''';

String dartBin() {
  try {
    return lookPath('dart', winHashBang: false).file;
  } on Exception {
    return null;
  }
}

String pubBin() {
  try {
    return lookPath('pub', winHashBang: false).file;
  } on Exception {
    return null;
  }
}

Future<void> downloadFile(Uri src, File out) async {
  stdout.writeln('Downloading: ${src}');

  var received = 0;
  var sink = out.openWrite();
  var client = http.Client();
  var response = await client.send(http.Request('GET', src));
  var progress = ProgressBar(complete: response.contentLength);

  await response.stream.map((s) {
    received += s.length;
    progress.update(received);
    return s;
  }).pipe(sink);

  await sink.close();
  client.close();

  progress.update(response.contentLength);
}

void extractZipFileSync(File zip, Directory out) {
  stdout.writeln('Extracting: ${zip.path} => ${out.path}');

  var extracted = 0;
  var archive = ZipDecoder().decodeBytes(zip.readAsBytesSync());
  var progress = ProgressBar(complete: archive.length);

  for (final item in archive) {
    if (item.isFile) {
      File(p.join(out.path, item.name.replaceFirst('dart-sdk/', '')))
        ..createSync(recursive: true)
        ..writeAsBytesSync(item.content);
      extracted += 1;
      progress.update(extracted);
    }
  }

  progress.update(archive.length);
}

List<String> findImports(String filepath) {
  var packages = <String>[];

  var ast = analyzer.parseFile(
    path: filepath,
    featureSet: FeatureSet.fromEnableFlags([]),
  );

  for (var directive in ast.unit.directives) {
    if (directive is ImportDirective) {
      var import = directive.uri.stringValue;
      if (import.startsWith('package:')) {
        packages.add(import.replaceFirst('package:', '').split('/')[0]);
      } else if (!import.startsWith('dart:')) {
        import = p.canonicalize(p.join(p.dirname(filepath), import));
        packages.addAll(findImports(import));
      }
    }
  }

  return Collection(packages).distinct().toList();
}

Future main(List<String> argv) async {
  // We shell out to both dart and pub so lets get their locations
  var dart = dartBin();
  var pub = pubBin();

  // Since it's possible someone has installed the dart2native version of this
  // binary we should check to make sure the dart sdk is installed and if not
  // we will install it.
  if (dart == null || pub == null) {
    var dartDir = Directory(p.join(
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'],
      '.dart',
    ));

    if (!dartDir.existsSync()) {
      stdout.writeln('Dart is not installed!');
      var tmpFolder = await Directory.systemTemp.createTemp();
      try {
        var url = 'https://storage.googleapis.com';
        url = '${url}/dart-archive/channels/stable/release/latest/sdk';
        url = '${url}/dartsdk-${Platform.operatingSystem}-x64-release.zip';
        var zipFile = File(p.join(tmpFolder.path, 'dart.zip'));
        await downloadFile(Uri.parse(url), zipFile);
        extractZipFileSync(zipFile, dartDir);
        if (!Platform.isWindows) {
          await dexeca('chmod', ['-R', '+x', p.join(dartDir.path, 'bin')]);
        }
      } finally {
        stdout.writeln('Deleting: ${tmpFolder.path}');
        await tmpFolder.delete(recursive: true);
      }
    }

    dart = p.join(dartDir.path, 'bin', 'dart');
    if (Platform.isWindows) {
      dart = dart + '.exe';
    }
    pub = p.join(dartDir.path, 'bin', 'pub');
    if (Platform.isWindows) {
      pub = pub + '.bat';
    }

    stdout.writeln();
    stdout.writeln('dart is being used from: ${dartDir.path}');
    stdout.writeln('suggest adding this to your \$PATH');
    stdout.writeln('This will speed up drun and remove this message.');
    stdout.writeln();
  }

  // Ensure the first argument points to a dart script to execute
  var args = <String>[...argv];
  if (argv?.isEmpty ?? true) {
    args = [_DEFAULT_SCRIPT];
  } else {
    if (!argv[0].startsWith('/') &&
        !argv[0].startsWith('./') &&
        !argv[0].startsWith('.\\') &&
        !argv[0].substring(1).startsWith(':\\') &&
        !argv[0].endsWith('.dart')) {
      args.insert(0, _DEFAULT_SCRIPT);
    }
  }

  // Check to see what files exist
  var cwd = p.canonicalize(p.dirname(args[0]));
  var results = await Future.wait([
    File(args[0]).exists(),
    File(p.join(cwd, '.packages')).exists(),
    File(p.join(cwd, 'pubspec.yaml')).exists()
  ]);

  // Output help info in the case the script to execute does not exist
  if (!results[0]) {
    if (argv.contains('--help') || argv.contains('-h')) {
      stdout.write(_HELP_TXT);
      exit(0);
    }

    if (argv.contains('--version') || argv.contains('-v')) {
      stdout.writeln(_VERSION);
      exit(0);
    }

    stderr.writeln('Error: expected to find ${p.canonicalize(args[0])}');
    stdout.writeln();
    stdout.write(_HELP_TXT);
    exit(1);
  }

  // If there is no pubspec file lets create one based on the packages imported
  if (!results[2]) {
    var packageRequests = <Future<http.Response>>[];
    for (var package in findImports(args[0])) {
      packageRequests.add(http.get(
        'https://pub.dartlang.org/api/packages/${package}',
        headers: {'Accept': 'application/vnd.pub.v2+json'},
      ));
    }

    dynamic pubspec = {'name': p.basename(cwd).snakeCase, 'dependencies': {}};
    await for (var response in Stream.fromFutures(packageRequests)) {
      if (response.statusCode == 200) {
        var payload = json.decode(response.body);
        var package = payload['name'];
        var version = payload['latest']['version'];
        pubspec['dependencies'][package] = '^${version}';
      } else {
        throw Exception(
          'request failed (${response.statusCode}): '
          '${response.request.method} ${response.request.url}',
        );
      }
    }

    var yaml = json2yaml(pubspec).toPubspecYaml().toYamlString();
    await File(p.join(cwd, 'pubspec.yaml')).writeAsString(yaml);
    results[2] = true;
  }

  // If we can find a pubspec.yaml file alongside the script we are
  // going to run without a correseponding .packages file then we will
  // make sure all dependencies are installed.
  if (!results[1] && results[2]) {
    await dexeca(
      pub,
      ['get'],
      inheritStdio: Platform.environment.containsKey('DRUN_DEBUG'),
      workingDirectory: cwd,
    );
  }

  // Execute the script, on *nix based systems this will replace
  // the process. On Windows it will spawn a new child process.
  dexecve(dart, args);

  // We should never get to here
  stderr.writeln('this is a bug, dexecve failed us');
  stderr.writeln('you could try `dart ${args.join(' ')}`');
  exit(1);
}
