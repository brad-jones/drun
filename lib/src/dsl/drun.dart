import 'dart:mirrors';

import 'package:args/args.dart';
import 'package:drun/src/dsl/copy.dart';
import 'package:drun/src/dsl/delete.dart';
import 'package:drun/src/dsl/depends.dart';
import 'package:drun/src/dsl/execute.dart';
import 'package:drun/src/dsl/global_options.dart';
import 'package:drun/src/dsl/logging.dart';
import 'package:drun/src/dsl/move.dart';
import 'package:drun/src/dsl/not_found_or_changed.dart';
import 'package:drun/src/dsl/once.dart';
import 'package:drun/src/dsl/realpath.dart';
import 'package:drun/src/dsl/search_replace.dart';

/// A class that builds the primary drun DSL.
class Drun
    with
        Logging,
        Realpath,
        Depends,
        Execute,
        Once,
        Copy,
        Move,
        Delete,
        NotFoundOrChanged,
        SearchReplace,
        GlobalOptions {
  Drun(
    String logPrefix,
    ArgResults argv,
    Map<String, String> env,
    Map<String, MethodMirror> options,
  ) {
    this.logPrefix = logPrefix;
    this.argv = argv;
    this.env = env;
    this.options = options;
  }
}
