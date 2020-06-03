import 'package:drun/src/dsl/copy.dart';
import 'package:drun/src/dsl/delete.dart';
import 'package:drun/src/dsl/depends.dart';
import 'package:drun/src/dsl/execute.dart';
import 'package:drun/src/dsl/logging.dart';
import 'package:drun/src/dsl/not_found_or_changed.dart';
import 'package:drun/src/dsl/once.dart';
import 'package:drun/src/dsl/realpath.dart';
import 'package:drun/src/dsl/search_replace.dart';

class Drun
    with
        Logging,
        Realpath,
        Depends,
        Execute,
        Once,
        Copy,
        Delete,
        NotFoundOrChanged,
        SearchReplace {
  Drun(String logPrefix) {
    this.logPrefix = logPrefix;
  }
}
