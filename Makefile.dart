#!/usr/bin/env -S pub run drun
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:dexeca/dexeca.dart';
import 'package:drun/drun.dart';
import 'package:path/path.dart' as p;
import 'package:pretty_json/pretty_json.dart';

/// TIP: Bootstrap this with `pub run drun`
Future<void> main(argv) async => drun(argv);

/// Gets things ready to perform a release.
///
/// * [nextVersion] Should be a valid semver version number string.
///   see: https://semver.org
///
///   This version number will be used to replace the `0.0.0-semantically-released`
///   placeholder in the files `./pubspec.yaml`, `./bin/drun.dart` &
///   `./lib/src/executor.dart`.
///
/// * [assetsDir] Files in this location will be uploaded to the new Github Release
Future<void> releasePrepare(
  String nextVersion, [
  String assetsDir = './github-assets',
]) async {
  await Future.wait([
    _searchReplaceVersion(File(p.absolute('pubspec.yaml')), nextVersion),
    _searchReplaceVersion(File(p.absolute('bin', 'drun.dart')), nextVersion),
    _searchReplaceVersion(
      File(p.absolute('lib', 'src', 'executor.dart')),
      nextVersion,
    ),
    () async {
      await generateArchives(nextVersion, assetsDir);
      await generateChecksums(assetsDir);
    }(),
  ]);
}

/// Takes the native binaries and creates distributable archives.
Future<void> generateArchives(
  String nextVersion, [
  String assetsDir = './github-assets',
]) async {
  var commonFiles = [
    File(p.absolute('README.md')),
    File(p.absolute('CHANGELOG.md')),
    File(p.absolute('LICENSE')),
  ];

  await Future.wait([
    // Generates drun-linux-x64.tar.gz, drun-linux-x64.rpm, drun-linux-x64.deb
    () async {
      var linuxFiles = await Directory(assetsDir)
          .list()
          .where((_) => _.path.contains('linux'))
          .map((_) => File.fromUri(_.uri))
          .toList();

      var archive = Archive();
      (await Future.wait([...commonFiles, ...linuxFiles].map(
        (_) async => ArchiveFile(
          _.path.endsWith('drun-linux-x64') ? 'drun' : p.basename(_.path),
          (await _.stat()).size,
          await _.readAsBytes(),
        ),
      )))
          .forEach((_) {
        if (_.name == 'drun') {
          _.mode = 493;
        }
        archive.addFile(_);
      });

      await File(p.join(assetsDir, 'drun-linux-x64.tar.gz')).writeAsBytes(
        GZipEncoder().encode(
          TarEncoder().encode(archive),
        ),
      );

      await dexeca('chmod', ['+x', p.join(assetsDir, 'drun-linux-x64')]);
      await _execNfpm(nextVersion, p.join(assetsDir, 'drun-linux-x64.rpm'));
      await _execNfpm(nextVersion, p.join(assetsDir, 'drun-linux-x64.deb'));

      await Future.wait(linuxFiles.map((_) => _.delete()));
    }(),

    // Generates drun-darwin-x64.tar.gz
    () async {
      var darwinFiles = await Directory(assetsDir)
          .list()
          .where((_) => _.path.contains('darwin'))
          .map((_) => File.fromUri(_.uri))
          .toList();

      var archive = Archive();
      (await Future.wait([...commonFiles, ...darwinFiles].map(
        (_) async => ArchiveFile(
          _.path.endsWith('drun-darwin-x64') ? 'drun' : p.basename(_.path),
          (await _.stat()).size,
          await _.readAsBytes(),
        ),
      )))
          .forEach((_) {
        if (_.name == 'drun') {
          _.mode = 493;
        }
        archive.addFile(_);
      });

      await File(p.join(assetsDir, 'drun-darwin-x64.tar.gz')).writeAsBytes(
        GZipEncoder().encode(
          TarEncoder().encode(archive),
        ),
      );

      await Future.wait(darwinFiles.map((_) => _.delete()));
    }(),

    // Generates drun-windows-x64.zip
    () async {
      var windowsFiles = await Directory(assetsDir)
          .list()
          .where((_) => _.path.contains('windows'))
          .map((_) => File.fromUri(_.uri))
          .toList();

      var zipFilePath = p.join(assetsDir, 'drun-windows-x64.zip');
      var zip = ZipFileEncoder();
      try {
        zip.create(zipFilePath);
        for (var f in [...commonFiles, ...windowsFiles]) {
          f.path.endsWith('drun-windows-x64')
              ? zip.addFile(f, 'drun.exe')
              : zip.addFile(f);
        }
        zip.close();
        await Future.wait(windowsFiles.map((_) => _.delete()));
      } catch (e) {
        zip.close();
        await File(zipFilePath).delete();
        rethrow;
      }
    }(),
  ]);
}

/// Creates the `drun-sha256-checksums.json` file.
///
/// SHA256 hashes are taken from all other files currently in the [assetsDir].
Future<void> generateChecksums([String assetsDir = './github-assets']) async {
  var hashes = <String, String>{};
  await for (var fse in Directory(assetsDir).list()) {
    var file = File.fromUri(fse.uri);
    hashes[p.basename(file.path)] =
        sha256.convert(await file.readAsBytes()).toString();
  }
  await File(p.absolute('github-assets', 'drun-sha256-checksums.json'))
      .writeAsString(prettyJson(hashes));
}

/// Actually publishes the package to https://pub.dev.
///
/// Beaware that `pub publish` does not really support being used inside a CI
/// pipeline yet. What this does is uses someone's local OAUTH creds which is a
/// bit hacky.
///
/// see: https://github.com/dart-lang/pub/issues/2227
/// also: https://medium.com/evenbit/publishing-dart-packages-with-github-actions-5240068a2f7d
///
/// * [nextVersion] Should be a valid semver version number string.
///   see: https://semver.org
///
/// * [dryRun] If supplied then nothing will actually get published.
///
/// * [assetsDir] This is required by the scoop and homebrew publish tasks.
///
/// * [accessToken] Get this from your local `credentials.json` file.
///
/// * [refreshToken] Get this from your local `credentials.json` file.
///
/// * [oAuthExpiration] Get this from your local `credentials.json` file.
///
/// * [homebrewGithubToken] A github token that has write permissions to the homebrew git repo.
///
/// * [scoopGithubToken] A github token that has write permissions to the scoop git repo.
Future<void> releasePublish(
  String nextVersion,
  bool dryRun, [
  String assetsDir = './github-assets',
  @Env('PUB_OAUTH_ACCESS_TOKEN') String accessToken = '',
  @Env('PUB_OAUTH_REFRESH_TOKEN') String refreshToken = '',
  @Env('PUB_OAUTH_EXPIRATION') int oAuthExpiration = 0,
  @Env('HOMEBREW_GITHUB_TOKEN') String homebrewGithubToken,
  @Env('SCOOP_GITHUB_TOKEN') String scoopGithubToken,
]) async {
  String tmpDir;
  var gitIgnore = File(p.absolute('.gitignore'));

  try {
    // Copy our custom .pubignore rules into .gitignore
    // see: https://github.com/dart-lang/pub/issues/2222
    tmpDir = (await Directory.systemTemp.createTemp('dexecve')).path;
    var pubIgnoreRulesFuture = File(p.absolute('.pubignore')).readAsString();
    await gitIgnore.copy(p.join(tmpDir, '.gitignore'));
    await gitIgnore.writeAsString(
      '\n${(await pubIgnoreRulesFuture)}',
      mode: FileMode.append,
    );

    if (dryRun) {
      await dexeca('pub', ['publish', '--dry-run'],
          runInShell: Platform.isWindows);
      return;
    }

    if (accessToken.isEmpty || refreshToken.isEmpty) {
      throw 'accessToken & refreshToken must be supplied!';
    }

    // on windows the path is actually %%UserProfile%%\AppData\Roaming\Pub\Cache
    // not that this really matters because we only intend on running this inside
    // a pipeline which will be running linux.
    var credsFilePath = p.join(_homeDir(), '.pub-cache', 'credentials.json');

    await File(credsFilePath).writeAsString(jsonEncode({
      'accessToken': '${accessToken}',
      'refreshToken': '${refreshToken}',
      'tokenEndpoint': 'https://accounts.google.com/o/oauth2/token',
      'scopes': ['openid', 'https://www.googleapis.com/auth/userinfo.email'],
      'expiration': oAuthExpiration,
    }));

    await dexeca('pub', ['publish', '--force'], runInShell: Platform.isWindows);
    await releaseHomebrew(nextVersion, assetsDir, homebrewGithubToken);
    await releaseScoop(nextVersion, assetsDir, scoopGithubToken);
  } finally {
    if (tmpDir != null) {
      if (await File(p.join(tmpDir, '.gitignore')).exists()) {
        await File(p.join(tmpDir, '.gitignore')).copy(gitIgnore.path);
      }
      await Directory(tmpDir).delete(recursive: true);
    }
  }
}

/// Publishes a new homebrew release
Future<void> releaseHomebrew(
  String nextVersion, [
  String assetsDir = './github-assets',
  @Env('HOMEBREW_GITHUB_TOKEN') String githubToken,
]) async {
  await dexeca('git', [
    'clone',
    '--progress',
    'https://${githubToken}@github.com/brad-jones/homebrew-tap.git',
    '/tmp/homebrew-tap'
  ]);

  var template = await File(p.absolute('brew.rb')).readAsString();
  template = template.replaceAll('{{VERSION}}', nextVersion);
  template = template.replaceAll(
    '{{HASH}}',
    sha256
        .convert(
          await File(p.join(assetsDir, 'drun-darwin-x64.tar.gz')).readAsBytes(),
        )
        .toString(),
  );
  await File('/tmp/homebrew-tap/Formula/drun.rb').writeAsString(template);

  await dexeca('git', ['add', '-A'], workingDirectory: '/tmp/homebrew-tap');
  await dexeca(
    'git',
    ['commit', '-m', 'chore(drun): release new version ${nextVersion}'],
    workingDirectory: '/tmp/homebrew-tap',
  );
  await dexeca(
    'git',
    ['push', 'origin', 'master'],
    workingDirectory: '/tmp/homebrew-tap',
  );
}

/// Publishes a new scoop release
Future<void> releaseScoop(
  String nextVersion, [
  String assetsDir = './github-assets',
  @Env('SCOOP_GITHUB_TOKEN') String githubToken,
]) async {
  await dexeca('git', [
    'clone',
    '--progress',
    'https://${githubToken}@github.com/brad-jones/scoop-bucket.git',
    '/tmp/scoop-bucket'
  ]);

  var template = await File(p.absolute('scoop.json')).readAsString();
  template = template.replaceAll('{{VERSION}}', nextVersion);
  template = template.replaceAll(
    '{{HASH}}',
    sha256
        .convert(
          await File(p.join(assetsDir, 'drun-windows-x64.zip')).readAsBytes(),
        )
        .toString(),
  );
  await File('/tmp/scoop-bucket/drun.json').writeAsString(template);

  await dexeca('git', ['add', '-A'], workingDirectory: '/tmp/scoop-bucket');
  await dexeca(
    'git',
    ['commit', '-m', 'chore(drun): release new version ${nextVersion}'],
    workingDirectory: '/tmp/scoop-bucket',
  );
  await dexeca(
    'git',
    ['push', 'origin', 'master'],
    workingDirectory: '/tmp/scoop-bucket',
  );
}

Future<void> _execNfpm(String version, String target) async {
  await dexeca('docker', [
    'run',
    '--rm',
    '-v',
    '${p.current}:${_forDocker(p.current)}',
    '-w',
    '${_forDocker(p.current)}',
    '-e',
    'VERSION=${version}',
    'goreleaser/nfpm:v1.1.10',
    'pkg',
    '--target',
    target,
  ]);
}

String _forDocker(String input) {
  if (Platform.isWindows) {
    return input.replaceAll('\\', '/').replaceFirst('C:', '');
  }
  return input;
}

String _homeDir() {
  if (Platform.isWindows) return Platform.environment['UserProfile'];
  return Platform.environment['HOME'];
}

Future<void> _searchReplaceFile(File file, String from, String to) async {
  var src = await file.readAsString();
  var newSrc = src.replaceAll(from, to);
  await file.writeAsString(newSrc);
}

Future<void> _searchReplaceVersion(File file, String nextVersion) {
  return _searchReplaceFile(file, '0.0.0-semantically-released', nextVersion);
}
