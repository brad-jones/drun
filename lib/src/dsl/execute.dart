import 'dart:cli';
import 'package:dexeca/dexeca.dart';
import 'package:drun/src/dsl/logging.dart';
import 'package:drun/src/dsl/realpath.dart';

mixin Execute on Realpath, Logging {
  /// Executes a child process.
  ///
  /// This is a customised version of [dexeca] that honours a tasks logging
  /// settings. For direct control over the child process, please use [dexeca]
  /// directly.
  ///
  /// see: https://pub.dev/packages/dexeca
  Future<ProcessResult> exe(
    String binary,
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
        binary,
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
      log(r.combinedOutput);
    } else {
      r = await dexeca(
        binary,
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
  ProcessResult exeSync(
    String binary,
    List<String> args, {
    String workingDirectory,
    Map<String, String> environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    bool winHashBang = true,
  }) {
    return waitFor(exe(
      binary,
      args,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      winHashBang: winHashBang,
    ));
  }
}
