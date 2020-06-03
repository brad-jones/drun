import 'dart:io';

import 'package:drun/src/dsl/logging.dart';
import 'package:drun/src/dsl/realpath.dart';

mixin Delete on Realpath, Logging {
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
}
