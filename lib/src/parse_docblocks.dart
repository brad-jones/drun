import 'dart:io';
import 'dart:convert';
import 'dart:mirrors';

class DocBlock {
  final String funcName;
  final String summary;
  final String description;
  final Map<String, String> parameters;

  DocBlock({
    this.funcName,
    this.summary,
    this.description,
    this.parameters,
  });
}

Future<List<DocBlock>> parseDocBlocks(
  String filePath,
  Iterable<MethodMirror> tasks,
) async {
  var docBlocks = <DocBlock>[];
  if (tasks.isEmpty) return docBlocks;

  var lines = await File(filePath).readAsLines();
  if (lines.isEmpty) return docBlocks;

  for (var task in tasks) {
    var funcName = MirrorSystem.getName(task.simpleName);
    var funcSignature = LineSplitter().convert(task.source).first;

    var docBlock = lines.reversed
        .skipWhile((_) => _ != funcSignature)
        .skip(1)
        .takeWhile((_) => _.startsWith('///'))
        .toList()
        .reversed
        .map((_) => _.replaceFirst('///', '').trimLeft());

    var parameters = <String, String>{};
    for (var parameter in task.parameters) {
      var paramName = MirrorSystem.getName(parameter.simpleName);
      parameters[paramName] = docBlock
          .skipWhile((_) => !_.startsWith('* [$paramName]'))
          .takeWhile(
              (_) => _.startsWith('* [$paramName]') || !_.startsWith('* ['))
          .map((_) => _.replaceFirst('* [$paramName] ', ''))
          .join('\n');
    }

    if (docBlock.isEmpty) {
      docBlocks.add(DocBlock(
        funcName: funcName,
        summary: '',
        description: '',
        parameters: parameters,
      ));
      continue;
    }

    docBlocks.add(DocBlock(
      funcName: funcName,
      summary: docBlock.first.trim(),
      description: docBlock
          .skip(1)
          .takeWhile((_) => !_.startsWith('* ['))
          .join('\n')
          .trim(),
      parameters: parameters,
    ));
  }

  docBlocks.sort((a, b) => a.funcName.compareTo(b.funcName));

  return docBlocks;
}
