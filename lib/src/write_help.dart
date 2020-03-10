import 'dart:io';
import 'dart:convert';
import 'dart:mirrors';
import 'package:args/args.dart';
import 'package:recase/recase.dart';
import 'package:console/console.dart';
import 'package:drun/drun.dart';
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
  ArgResults parsedArgv,
  Iterable<MethodMirror> tasks,
) async {
  Console.init();

  // Start parsing the makefile for docblocks
  var docBlocksFuture = parseDocBlocks(Platform.script.toFilePath(), tasks);

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
    for (var docBlock in docBlocks) {
      Console.setBold(true);
      stdout.write('  ${docBlock.funcName.paramCase}');
      Console.resetAll();
      stdout.write(': ${docBlock.summary}');
      stdout.writeln();
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
    var task = tasks.singleWhere(
        (_) => _.simpleName == Symbol(parsedArgv.command.name.camelCase));
    var docBlock = docBlocks
        .singleWhere((_) => _.funcName == parsedArgv.command.name.camelCase);
    for (var parameter in docBlock.parameters.entries) {
      var p = task.parameters
          .singleWhere((_) => _.simpleName == Symbol(parameter.key));

      Console.setBold(true);
      Console.setUnderline(true);
      Console.setTextColor(Color.GRAY.id);

      var buffer1 = StringBuffer();
      buffer1.write('  --${parameter.key}');
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

  // Output out global options
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

  await stdout.flush();
}
