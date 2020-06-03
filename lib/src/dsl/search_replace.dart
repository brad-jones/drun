import 'dart:io';

import 'package:drun/src/dsl/realpath.dart';

mixin SearchReplace on Realpath {
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
