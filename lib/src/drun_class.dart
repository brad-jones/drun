import 'dart:io';

import 'package:dexeca/dexeca.dart';
import 'package:glob/glob.dart';
import 'package:mustache_template/mustache_template.dart';
import 'package:path/path.dart' as p;

import 'package:drun/src/utils.dart';

/// Each drun [task] has an instance of this class injected.
class Drun {
  String _logPrefix;
  bool _logBuffered;
  String _logBufferedTpl;
  String _logPrefixSeperator;
  final List<String> _logBuffer = <String>[];

  Drun(
    String logPrefix,
    bool logBuffered,
    String logBufferedTpl,
    String logPrefixSeperator,
  ) {
    _logPrefix = logPrefix;
    _logBuffered = logBuffered;
    _logBufferedTpl = logBufferedTpl;
    _logPrefixSeperator = logPrefixSeperator;
  }

  /// Logs the given [message] to `stdout`.
  ///
  /// This method honours the configuration passed to [task],
  /// such as `logPrefix`, `logPrefixSeperator` & `logBuffered`.
  ///
  /// Example usage:
  ///
  /// ```dart
  /// Future build() => task((drun) {
  ///   drun.log('building project...');
  /// });
  /// ```
  void log(String message) {
    if (_logBuffered) {
      _logBuffer.add(message);
    } else {
      stdout.writeln('${_logPrefix}${_logPrefixSeperator}${message}');
    }
  }

  /// If `logBuffered` is true then all messages written by [log] will be
  /// stored in memory, this method is used to output those messages all
  /// at once.
  ///
  /// Calling this directly is considered advanced usage,
  /// this is called by [task] if required.
  void writeBufferedLogs() {
    if (_logBuffer.isNotEmpty) {
      if (_logBufferedTpl?.isNotEmpty ?? false) {
        stdout.write(
          Template(_logBufferedTpl).renderString({'prefix': _logPrefix}),
        );
      }
      stdout.writeAll(_logBuffer, '\n');
      if (_logBufferedTpl?.isNotEmpty ?? false) {
        stdout.write('\n\n');
      }
    }
  }

  /// Canonicalizes [path].
  ///
  /// This is guaranteed to return the same path for two different input paths
  /// if and only if both input paths point to the same location.
  ///
  /// Additionally some convenience replacements are performed:
  /// - When [path] starts with `~` it will be replaced with users home dir
  /// - When [path] starts with `!` it will be replaced by the projects root dir
  ///
  /// The projects root dir is assumed to be where a `.git` folder is found.
  /// Consider this example:
  ///
  /// - `/home/user/acme-project`
  ///   - .git
  ///   - assets
  ///     - image.jpg
  ///   - Makefile.dart: `realpath('!/assets/image.jpg')` = `/home/user/acme-project/assets/image.jpg`
  ///     - projects
  ///       - foo
  ///         - Makefile.dart `realpath('!/assets/image.jpg')` = `/home/user/acme-project/assets/image.jpg`
  ///       - bar
  ///         - Makefile.dart `realpath('!/assets/image.jpg')` = `/home/user/acme-project/assets/image.jpg`
  ///
  /// So regardless of if the working directory is `/home/user/acme-project` and
  /// child Makefiles have been included or the current working directory is
  /// `/home/user/acme-project/projects/foo` and the user is operating `drun`
  /// against a standalone Makefile, paths can always be resolved correctly.
  ///
  /// If this logic is not suitable (eg: git is not being used) then you may
  /// provide your very own [rootFinder] function.
  String realpath(String path, {String Function() rootFinder}) {
    if (!p.isAbsolute(path)) {
      if (path.startsWith('~')) {
        path = p.join(
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'],
          path.substring(1),
        );
      } else if (path.startsWith('!')) {
        path = p.join(_repoRoot(rootFinder), path.substring(1));
      }
    }
    return p.canonicalize(path);
  }

  static String _repoRootCache;
  static String _repoRoot([String Function() rootFinder]) {
    if (_repoRootCache == null) {
      if (rootFinder != null) {
        _repoRootCache = rootFinder();
      } else {
        var dir = Directory.current;
        while (!Directory(p.join(dir.path, '.git')).existsSync()) {
          dir = dir.parent;
        }
        _repoRootCache = p.canonicalize(dir.path);
      }
    }
    return _repoRootCache;
  }

  /// Executes a child process.
  ///
  /// This is a customised version of [dexeca] that honours a tasks logging
  /// settings. For direct control over the child process, please use [dexeca]
  /// directly.
  ///
  /// see: https://pub.dev/packages/dexeca
  Future<ProcessResult> run(
    String exe,
    List<String> args, {
    String workingDirectory,
    Map<String, String> environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    bool winHashBang = true,
  }) async {
    ProcessResult r;

    if (workingDirectory != null) {
      workingDirectory = realpath(workingDirectory);
    }

    if (_logBuffered) {
      r = await dexeca(
        exe,
        args,
        workingDirectory: workingDirectory,
        environment: environment,
        inheritStdio: false,
        captureOutput: true,
        combineOutput: true,
        includeParentEnvironment: includeParentEnvironment,
        runInShell: runInShell,
        winHashBang: winHashBang,
      );
      _logBuffer.addAll(r.combinedOutput.replaceAll('\r\n', '\n').split('\n'));
    } else {
      r = await dexeca(
        exe,
        args,
        prefix: _logPrefix,
        prefixSeperator: _logPrefixSeperator,
        workingDirectory: workingDirectory,
        environment: environment,
        inheritStdio: true,
        captureOutput: false,
        includeParentEnvironment: includeParentEnvironment,
        runInShell: runInShell,
        winHashBang: winHashBang,
      );
    }

    return r;
  }

  /// Copies [source] to [destination] regardless if a single file
  /// or entire folders. [excludes] are matched using [Glob].
  ///
  /// Returns a list of file paths that were copied.
  Future<List<String>> copy(
    String src,
    String dst, {
    List<String> excludes,
  }) async {
    src = realpath(src);
    dst = realpath(dst);
    if (await File(src).exists()) {
      await _copyFile(File(src), File(dst));
      return [p.canonicalize(dst)];
    }
    return _copyDirectory(
      Directory(src),
      Directory(dst),
      excludes: excludes,
    );
  }

  Future<void> _copyFile(File src, File dst) async {
    var dir = Directory(p.dirname(dst.path));
    if (!await dir.exists()) await dir.create(recursive: true);
    await dst.writeAsBytes(await src.readAsBytes());
    log('copied ${p.relative(src.path)} => ${p.relative(dst.path)}');
  }

  Future<List<String>> _copyDirectory(
    Directory source,
    Directory destination, {
    List<String> excludes,
    String initalSrc,
    String initalDst,
  }) async {
    if (initalSrc == null) {
      log('copying ${source.path} => ${destination.path}');
    }
    initalSrc ??= source.path;
    initalDst ??= destination.path;

    var copiedFiles = <String>[];

    await for (var entity in source.list(recursive: false)) {
      if (entity is Directory) {
        var newDirectory = Directory(
          p.join(
            destination.absolute.path,
            p.basename(entity.path),
          ),
        );
        await newDirectory.create();
        var copiedFiles2 = await _copyDirectory(
          entity.absolute,
          newDirectory,
          excludes: excludes,
          initalSrc: initalSrc,
          initalDst: initalDst,
        );
        if (copiedFiles2.isEmpty) {
          await newDirectory.delete();
        } else {
          copiedFiles.addAll(copiedFiles2);
        }
      } else if (entity is File) {
        var copy = true;
        if (excludes != null) {
          for (var exclude in excludes) {
            if (Glob(fixGlobForWindows(exclude)).matches(entity.path)) {
              copy = false;
              break;
            }
          }
        }
        if (copy) {
          var dst = p.join(destination.path, p.basename(entity.path));
          await entity.copy(dst);
          copiedFiles.add(dst);
          log('copied ${p.relative(entity.path, from: initalSrc)}');
        }
      }
    }

    return copiedFiles;
  }

  /// Deletes the [path] recursivly, regardless if a file or directory.
  Future<void> del(String path) async {
    path = realpath(path);
    var fT = (await File(path).stat()).type;
    if (fT != FileSystemEntityType.notFound) {
      if (fT == FileSystemEntityType.directory) {
        await Directory(path).delete(recursive: true);
      } else {
        await File(path).delete(recursive: true);
      }
      log('deleted ${path}');
    }
  }

  /// Loops through each [from] pattern looking for all matches in [input] and
  /// replacing them with the same index of [to]. If [to] is not the same length
  /// as [from] then the last element of [to] will be used for all remaining
  /// replacements.
  ///
  /// For example:
  ///
  /// ```dart
  /// searchReplace('foo bar baz', ['foo'], ['hello']) == 'hello bar baz';
  /// searchReplace('foo bar baz', ['foo', 'bar', 'baz'], ['hello']) == 'hello hello hello';
  /// searchReplace('foo bar baz', ['foo', 'bar', 'baz'], ['hello', 'goodbye']) == 'hello goodbye goodbye';
  /// searchReplace('foo bar baz', ['foo', 'bar', 'baz'], ['hello', 'goodbye', 'foobar']) == 'hello goodbye foobar';
  /// ```
  String searchReplace(
    String input,
    List<Pattern> from,
    List<String> to,
  ) {
    for (var i = 0; i < from.length; i++) {
      input = input.replaceAll(
        from[i],
        to.length > i ? to[i] : to[to.length - 1],
      );
    }
    return input;
  }

  /// Reads [path] into a string and uses the same logic as [searchReplace] on the
  /// content. It then writes the result back to [path] or [outPath] if supplied.
  Future<void> searchReplaceFile(
    String path,
    List<Pattern> from,
    List<String> to, {
    String outPath,
  }) async {
    var file = File(realpath(path));
    var content = await file.readAsString();
    content = searchReplace(content, from, to);
    if (outPath == null) {
      await file.writeAsString(content);
    } else {
      await File(realpath(outPath)).writeAsString(content);
    }
  }
}
