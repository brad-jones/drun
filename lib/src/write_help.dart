import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';

import 'package:args/args.dart';
import 'package:console/console.dart';
import 'package:recase/recase.dart';

import 'package:drun/src/annotations.dart';
import 'package:drun/src/parse_docblocks.dart';

const String asciiArt = '''
    ________
    \\______ \\_______ __ __  ____
     |    |  \\_  __ \\  |  \\/    \\
     |    `   \\  | \\/  |  /   |  \\
    /_______  /__|  |____/|___|  /
            \\/                 \\/
  https://github.com/brad-jones/drun
        A dartlang task runner
''';

Future<void> writeHelp(
  Map<String, MethodMirror> tasks,
  Map<String, MethodMirror> options,
  ArgResults parsedArgv,
  bool showSubtasks,
) async {
  Console.init();

  // Start parsing the makefile for docblocks
  var docBlocksFuture = parseDocBlocks(tasks);
  var globalOptionsFuture = parseDocBlocks(options);

  // Now do what we can to get some pixels on the screen as soon as possible
  if (parsedArgv.command == null) {
    Console.setTextColor(Color.CYAN.id);
    stdout.writeln(asciiArt);
    Console.setBold(true);
    Console.setTextColor(Color.DARK_BLUE.id);
    stdout.writeln('drun <task>');
  } else {
    Console.setBold(true);
    Console.setTextColor(Color.DARK_BLUE.id);
    stdout.writeln('drun ${parsedArgv.command.name}');
  }
  stdout.writeln();
  Console.resetAll();
  await stdout.flush();

  // We need the metadata to output the rest of the help
  var docBlocks = await docBlocksFuture;

  if (parsedArgv.command == null) {
    // output a list of tasks
    stdout.writeln('Tasks:');
    for (var docBlock in docBlocks.where((_) => !_.funcName.contains(':'))) {
      Console.setBold(true);
      stdout.write('  ${docBlock.funcName}');
      Console.resetAll();
      stdout.write(': ${docBlock.summary}');
      stdout.writeln();
    }

    // If enabled output a list of all sub tasks
    // NOTE: Sub Tasks can still be called regardless of this setting
    if (showSubtasks) {
      var subTasks = docBlocks.where((_) => _.funcName.contains(':'));
      if (subTasks.isNotEmpty) {
        stdout.writeln();
        stdout.writeln('Sub Tasks:');
        for (var docBlock in subTasks) {
          Console.setBold(true);
          stdout.write('  ${docBlock.funcName}');
          Console.resetAll();
          stdout.write(': ${docBlock.summary}');
          stdout.writeln();
        }
      }
    }
    stdout.writeln();
  } else {
    // output help text for a specfic task
    if (docBlocks[0].summary.isNotEmpty) {
      stdout.writeln(docBlocks[0].summary);
      stdout.writeln();
    }
    if (docBlocks[0].description.isNotEmpty) {
      stdout.writeln(docBlocks[0].description);
      stdout.writeln();
    }
  }

  // Output the options for the task
  stdout.writeln('Options:');
  if (parsedArgv.command != null) {
    var task = tasks[parsedArgv.command.name];
    var docBlock =
        docBlocks.singleWhere((_) => _.funcName == parsedArgv.command.name);
    for (var parameter in docBlock.parameters.entries) {
      var p = task.parameters
          .singleWhere((_) => _.simpleName == Symbol(parameter.key));

      Console.setBold(true);
      Console.setUnderline(true);
      Console.setTextColor(Color.GRAY.id);

      var buffer1 = StringBuffer();
      buffer1.write('  --${parameter.key.paramCase}');
      if (Abbr.hasMetadata(p)) {
        buffer1.write(',-${Abbr.fromMetadata(p).value}');
      }
      var optFlags = buffer1.toString();
      stdout.write(optFlags);

      var buffer2 = StringBuffer();
      buffer2.write('[${p.type.reflectedType.toString().toLowerCase()}]');
      if (p.type.reflectedType.toString().startsWith('List<')) {
        buffer2.write('csv');
      }
      if (!p.isOptional && p.type.reflectedType != bool) {
        buffer2.write(' "required"');
      }
      if (Env.hasMetadata(p)) {
        buffer2.write(' <env:${Env.fromMetadata(p).value}>');
      }
      if (Values.hasMetadata(p)) {
        buffer2.write(' valid: ${Values.fromMetadata(p).values}');
      }
      if (p.hasDefaultValue) {
        buffer2.write(' (default: "${p.defaultValue.reflectee.toString()}")');
      }
      var optMeta = buffer2.toString();
      stdout.write(optMeta.padLeft(80 - optFlags.length));
      stdout.writeln();
      Console.resetAll();

      if (parameter.value.isNotEmpty) {
        stdout.writeln(
          LineSplitter()
              .convert(parameter.value)
              .map((_) => '  ${_}')
              .join('\n'),
        );
      } else {
        stdout.writeln('  **undocumented**');
      }
      stdout.writeln();
    }
  }

  // Output global options
  var globalOptions = await globalOptionsFuture;
  if (globalOptions.isNotEmpty) {
    for (var option in options.entries) {
      Console.setBold(true);
      Console.setUnderline(true);
      Console.setTextColor(Color.GRAY.id);

      var buffer1 = StringBuffer();
      buffer1.write('  --${option.key}');
      if (Abbr.hasMetadata(option.value)) {
        buffer1.write(',-${Abbr.fromMetadata(option.value).value}');
      }
      var optFlags = buffer1.toString();
      stdout.write(optFlags);

      var buffer2 = StringBuffer();
      buffer2.write(
          '[${option.value.returnType.reflectedType.toString().toLowerCase()}]');
      if (option.value.returnType.reflectedType
          .toString()
          .startsWith('List<')) {
        buffer2.write('csv');
      }
      if (Required.hasMetadata(option.value) &&
          Required.fromMetadata(option.value).value &&
          option.value.returnType.reflectedType != bool) {
        buffer2.write(' "required"');
      }
      if (Env.hasMetadata(option.value)) {
        buffer2.write(' <env:${Env.fromMetadata(option.value).value}>');
      }
      if (Values.hasMetadata(option.value)) {
        buffer2.write(' valid: ${Values.fromMetadata(option.value).values}');
      }
      //if (option.value.hasDefaultValue) {
      //  buffer2.write(' (default: "${option.value.defaultValue.reflectee.toString()}")');
      //}
      var optMeta = buffer2.toString();
      stdout.write(optMeta.padLeft(80 - optFlags.length));
      stdout.writeln();
      Console.resetAll();

      var docBlock = globalOptions.singleWhere((_) => _.funcName == option.key);
      if (docBlock.summary.isNotEmpty) {
        stdout.writeln(
          LineSplitter()
              .convert('${docBlock.summary}\n${docBlock.description}')
              .map((_) => '  ${_}')
              .join('\n'),
        );
      } else {
        stdout.writeln('  **undocumented**');
      }
      stdout.writeln();
    }
  }

  // Output our built-in options
  Console.setBold(true);
  Console.setUnderline(true);
  Console.setTextColor(Color.GRAY.id);
  var versionFlag = '  --version,-v';
  stdout.write(versionFlag);
  stdout.write('[bool]'.padLeft(80 - versionFlag.length));
  stdout.writeln();
  Console.resetAll();
  stdout.writeln('  Shows the version number of drun.');
  stdout.writeln();

  Console.setBold(true);
  Console.setUnderline(true);
  Console.setTextColor(Color.GRAY.id);
  var helpFlag = '  --help,-h';
  stdout.write(helpFlag);
  stdout.write('[bool]'.padLeft(80 - helpFlag.length));
  stdout.writeln();
  Console.resetAll();
  stdout.writeln('  Shows this help text for any task.');
  stdout.writeln();

  Console.setBold(true);
  Console.setUnderline(true);
  Console.setTextColor(Color.GRAY.id);
  var showSubTasksFlag = '  --show-subtasks';
  stdout.write(showSubTasksFlag);
  stdout.write(
      '<env:DRUN_SHOW_SUBTASKS> [bool]'.padLeft(80 - showSubTasksFlag.length));
  stdout.writeln();
  Console.resetAll();
  stdout
      .writeln('  Shows tasks from other included Makefiles on the help page.');
  stdout.writeln();

  Console.setBold(true);
  Console.setUnderline(true);
  Console.setTextColor(Color.GRAY.id);
  var logBufferedFlag = '  --log-buffered';
  stdout.write(logBufferedFlag);
  stdout.write(
      '<env:DRUN_LOG_BUFFERED> [bool]'.padLeft(80 - logBufferedFlag.length));
  stdout.writeln();
  Console.resetAll();
  stdout.writeln('  If set then logs will be buffered and output in groups.');
  stdout.writeln();

  Console.setBold(true);
  Console.setUnderline(true);
  Console.setTextColor(Color.GRAY.id);
  var logColorsFlag = '  --no-log-colors';
  stdout.write(logColorsFlag);
  stdout.write(
      '<env:DRUN_NO_LOG_COLORS> [bool]'.padLeft(80 - logColorsFlag.length));
  stdout.writeln();
  Console.resetAll();
  stdout.writeln('  If set then logs will not contain terminal colors.');
  stdout.writeln();

  await stdout.flush();
}
