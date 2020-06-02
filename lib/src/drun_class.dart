import 'dart:async';
import 'dart:cli';
import 'dart:io';
import 'dart:mirrors';

import 'package:async/async.dart';
import 'package:dexeca/dexeca.dart';
import 'package:glob/glob.dart';
import 'package:mustache_template/mustache_template.dart';
import 'package:path/path.dart' as p;

import 'package:drun/src/utils.dart';
import 'package:drun/src/logging.dart' as logging;

class Drun {
  String _logPrefix;

  /// A custom log prefix to use for any messages output with [log].
  /// By default this will use reflection and use the name of the task.
  String get logPrefix => _logPrefix;

  /// A custom log prefix to use for any messages output with [log].
  /// By default this will use reflection and use the name of the task.
  set logPrefix(String v) => _logPrefix = logging.colorize(v);

  /// If set to true then all logs for this task will be stored in memory until
  /// the task is complete and then output all at once in a group with a heading
  /// of [logPrefix].
  bool logBuffered = false;
  final List<String> _logBuffer = <String>[];

  /// If [logBuffered] is true then this mustache template will be used to
  /// output the [logPrefix] as a heading for the group of buffered logs.
  /// If this is set to an empty string or null then no heading will be output.
  String logBufferedTpl = logging.bufferedTplDefault;

  /// The string that is used between [logPrefix] and the log message.
  String logPrefixSeperator = logging.prefixSeperatorDefault;

  Drun(String logPrefix) {
    this.logPrefix = logPrefix;
    logBuffered = logging.buffered;
    logBufferedTpl = logging.bufferedTpl;
    logPrefixSeperator = logging.prefixSeperator;
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
    if (logBuffered) {
      _logBuffer.add(message);
    } else {
      stdout.writeln('${logPrefix}${logPrefixSeperator}${message}');
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
      if (logBufferedTpl?.isNotEmpty ?? false) {
        stdout.write(
          Template(logBufferedTpl).renderString({'prefix': logPrefix}),
        );
      }
      stdout.writeAll(_logBuffer, '\n');
      if (logBufferedTpl?.isNotEmpty ?? false) {
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

    if (logBuffered) {
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
        prefix: logPrefix,
        prefixSeperator: logPrefixSeperator,
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

  /// A synchronous version of [run].
  ProcessResult runSync(
    String exe,
    List<String> args, {
    String workingDirectory,
    Map<String, String> environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    bool winHashBang = true,
  }) {
    return waitFor(run(
      exe,
      args,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      winHashBang: winHashBang,
    ));
  }

  static final _onceTasks = <String, AsyncMemoizer>{};

  /// Given any parameterless function this will only ever execute it once.
  /// On subsequent executions that first result is returned.
  ///
  /// Every time an annoymous function is created in dart lang it is
  /// considered unique from all other instances of the same function.
  /// Consider the following example:
  ///
  /// ```dart
  /// Future foo() => task((drun) => drun.runOnce(() => print('hello')));
  ///
  /// Future bar() => task((drun) async {
  ///   await foo();
  ///   await foo();
  ///   await foo();
  /// });
  /// ```
  ///
  /// Executing `drun bar` would print `hello` 3 times. However this example:
  ///
  /// ```dart
  /// var x = () => print('hello');
  ///
  /// Future foo() => task((drun) => drun.runOnce(x));
  ///
  /// Future bar() => task((drun) async {
  ///   await foo();
  ///   await foo();
  ///   await foo();
  /// });
  /// ```
  ///
  /// Only prints `hello` once. To make life easier for most cases we use
  /// reflection to get the source code of the [computation] and create a hash
  /// to use for comparision purposes.
  ///
  /// This works for many cases however sometimes you might have 2 functions
  /// with the exact same source code, but perhaps are differentiated by
  /// constants or other variables.
  ///
  /// If that is the case you can specify your own unique [key] such as a UUID.
  Future<T> runOnce<T>(FutureOr<T> Function() computation, {String key}) async {
    if (key == null) {
      var reflected = reflect(computation) as ClosureMirror;
      key = md5String(reflected.function.source);
    }
    if (!_onceTasks.containsKey(key)) {
      _onceTasks[key] = AsyncMemoizer<T>();
    }
    return _onceTasks[key].runOnce(computation);
  }

  /// This function will return `false` the moment a glob pattern does not
  /// return any valid results. If all glob patterns return at least a single
  /// valid path then this function will return `true`.
  Future<bool> exists(List<String> globs) async {
    for (var glob in globs) {
      var found = false;
      try {
        await for (var _ in Glob(fixGlobForWindows(glob)).list()) {
          found = true;
          break;
        }
      } on FileSystemException {
        found = false;
      }
      if (!found) {
        return false;
      }
    }
    return true;
  }

  /// A synchronous version of [exists].
  bool existsSync(List<String> globs) {
    return waitFor(exists(globs));
  }

  /// This function will return `true` if any files found with [globs] have
  /// changed since the last execution of this method, otherwise `false`
  /// will be returned.
  Future<bool> changed(
    List<String> globs, {
    ChangedMethod method = ChangedMethod.timestamp,
  }) async {
    var currentState = await _getCurrentState(globs, method);

    String previousState;
    var previousStateFile =
        await File(p.absolute('.drun_tool', 'run-if-changed-state'));
    if (await previousStateFile.exists()) {
      previousState = await previousStateFile.readAsString();
    } else {
      await previousStateFile.create(recursive: true);
    }

    return currentState != previousState;
  }

  /// A synchronous version of [changed].
  bool changedSync(
    List<String> globs, {
    ChangedMethod method = ChangedMethod.timestamp,
  }) {
    return waitFor(changed(globs, method: method));
  }

  /// This method combines both [exists] & [changed] into a single call.
  ///
  /// If [existGlobs] returns no matches then this function will save the
  /// current state of the [changedGlobs] and return `true`.
  ///
  /// Otherwise [changed] is called and the result returned.
  Future<bool> notFoundOrChanged(
    List<String> existGlobs,
    List<String> changedGlobs, {
    ChangedMethod method = ChangedMethod.timestamp,
  }) async {
    if (!await exists(existGlobs)) {
      await _saveCurrentState(changedGlobs, method);
      return true;
    }
    return await changed(changedGlobs, method: method);
  }

  /// A synchronous version of [notFoundOrChangedSync].
  bool notFoundOrChangedSync(
    List<String> existGlobs,
    List<String> changedGlobs, {
    ChangedMethod method = ChangedMethod.timestamp,
  }) {
    return waitFor(notFoundOrChanged(existGlobs, changedGlobs, method: method));
  }

  Future<String> _getCurrentState(
    List<String> globs,
    ChangedMethod method,
  ) async {
    var currentStateItems = <String, String>{};
    for (var glob in globs) {
      await for (var f in Glob(fixGlobForWindows(glob)).list()) {
        String value;
        if (method == ChangedMethod.timestamp) {
          value = (await f.stat()).modified.microsecondsSinceEpoch.toString();
        } else {
          value = await sha256File(f.path).toString();
        }
        currentStateItems[p.canonicalize(f.path)] = value;
      }
    }

    var currentStateBuffer = StringBuffer();
    for (var k in currentStateItems.keys.toList()..sort()) {
      currentStateBuffer.write(k);
      currentStateBuffer.write(currentStateItems[k]);
    }

    return sha256String(currentStateBuffer.toString());
  }

  Future<void> _saveCurrentState(
    List<String> globs,
    ChangedMethod method,
  ) async {
    var currentState = await _getCurrentState(globs, method);
    await (await File(p.absolute('.drun_tool', 'run-if-changed-state'))
            .create(recursive: true))
        .writeAsString(currentState);
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

/// When using [changed] this functionality will default to using the
/// files [timestamp] for comparison or you can use a [checksum] which
/// will be more accurate but slower.
enum ChangedMethod { checksum, timestamp }
