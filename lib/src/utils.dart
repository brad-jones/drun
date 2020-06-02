import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

String md5String(String value) {
  return md5.convert(utf8.encode(value)).toString();
}

String sha256String(String value) {
  return sha256.convert(utf8.encode(value)).toString();
}

Future<Digest> sha256File(String path) async {
  var output = AccumulatorSink<Digest>();
  var input = sha256.startChunkedConversion(output);
  await for (var chunk in File(path).openRead()) {
    input.add(chunk);
  }
  input.close();
  return output.events.single;
}

String fixGlobForWindows(String glob) {
  return glob.replaceAll('\\', '/');
}
