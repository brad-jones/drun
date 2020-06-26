import 'dart:convert';
import 'dart:io';
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

Map<Uri, List<String>> _srcFiles = {};

Future<List<DocBlock>> parseDocBlocks(
  Map<String, MethodMirror> methods,
) async {
  var docBlocks = <DocBlock>[];
  if (methods?.isEmpty ?? true) return docBlocks;

  for (var e in methods.entries) {
    if (!_srcFiles.containsKey(e.value.location.sourceUri)) {
      _srcFiles[e.value.location.sourceUri] =
          (await File.fromUri(e.value.location.sourceUri).readAsLines())
              .map((line) => line.trimLeft())
              .toList();
    }
    var lines = _srcFiles[e.value.location.sourceUri];

    var funcSignature = LineSplitter().convert(e.value.source).first;

    var docBlock = lines.reversed
        .skipWhile((_) => _ != funcSignature)
        .skip(1)
        .takeWhile((_) => _.startsWith('///'))
        .toList()
        .reversed
        .map((_) => _.replaceFirst('///', '').trimLeft());

    var parameters = <String, String>{};
    for (var parameter in e.value.parameters) {
      var paramName = MirrorSystem.getName(parameter.simpleName);
      if (paramName == 'argv' &&
          parameter.type.reflectedType.toString() == 'List<String>') {
        continue;
      }
      parameters[paramName] = docBlock
          .skipWhile((_) => !_.startsWith('* [$paramName]'))
          .takeWhile(
              (_) => _.startsWith('* [$paramName]') || !_.startsWith('* ['))
          .map((_) => _.replaceFirst('* [$paramName] ', ''))
          .join('\n');
    }

    if (docBlock.isEmpty) {
      docBlocks.add(DocBlock(
        funcName: e.key,
        summary: '',
        description: '',
        parameters: parameters,
      ));
      continue;
    }

    docBlocks.add(DocBlock(
      funcName: e.key,
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
