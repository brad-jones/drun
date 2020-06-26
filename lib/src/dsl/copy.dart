import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import 'package:drun/src/dsl/logging.dart';
import 'package:drun/src/dsl/realpath.dart';
import 'package:drun/src/utils.dart';

mixin Copy on Realpath, Logging {
  /// Copies [src] to [dst] regardless if a single file
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
}
