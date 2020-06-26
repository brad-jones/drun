import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:drun/src/dsl/logging.dart';
import 'package:drun/src/dsl/realpath.dart';

mixin Move on Realpath, Logging {
  /// Moves [src] to [dst] regardless if a single file
  /// or entire folders.
  ///
  /// Returns a the new path
  Future<String> move(String src, String dst) async {
    src = realpath(src);
    dst = realpath(dst);

    String moved;
    var fT = (await File(src).stat()).type;
    if (fT != FileSystemEntityType.notFound) {
      if (fT == FileSystemEntityType.directory) {
        moved = (await Directory(src).rename(dst)).path;
      } else {
        moved = (await File(src).rename(dst)).path;
      }
      log('moved ${p.relative(src)} => ${p.relative(dst)}');
      return moved;
    }

    throw FileSystemException('not found', src);
  }
}
