import 'dart:io';
import 'dart:math';
import 'package:ansicolor/ansicolor.dart';
import 'package:mustache_template/mustache.dart';

mixin Logging {
  // ---------------------------------------------------------------------------
  String _logPrefix;

  /// Gets the log prefix to use for any messages output with [log].
  String get logPrefix => _logPrefix;

  /// Sets the log prefix to use for any messages output with [log].
  set logPrefix(String v) => _logPrefix = _colorize(v);

  // ---------------------------------------------------------------------------
  bool _logBuffered;
  final List<String> _logBuffer = <String>[];

  /// Gets the buffered logging mode.
  ///
  /// If this instance has no value set,
  /// then the global value of [buffered] is returned.
  bool get logBuffered => _logBuffered ?? buffered;

  /// Sets the buffered logging mode.
  ///
  /// If `true` then [log] will store all `messages` into memory
  /// instead of printing them immediately.
  set logBuffered(bool v) => _logBuffered = v;

  /// A global default value that can be set via the main [drun] method,
  /// the cli flag `--log-buffered` or an environment variable
  /// `DRUN_LOG_BUFFERED`.
  static bool buffered = false;

  // ---------------------------------------------------------------------------
  String _logBufferedTpl;

  /// Gets the buffered logging mustache template.
  ///
  /// If this instance has no value set,
  /// then the global value of [bufferedTpl] is returned.
  String get logBufferedTpl => _logBufferedTpl ?? bufferedTpl;

  /// Sets the buffered logging mustache template.
  ///
  /// If [logBuffered] is true then this mustache template will be used to
  /// output the [logPrefix] as a heading for the group of buffered logs.
  /// If this is set to an empty string or null then no heading will be output.
  set logBufferedTpl(String v) => _logBufferedTpl = v;

  /// A global default value that can be set via the main [drun] method,
  /// or an environment variable `DRUN_LOG_BUFFERED_TPL`.
  static String bufferedTpl =
      '>>> {{prefix}}\n--------------------------------------------------------------------------------\n{{logs}}\n\n';

  // ---------------------------------------------------------------------------
  String _logPrefixSeperator;

  /// Gets the logging prefix seperator, a string prefixed to any `message`
  /// given to [log].
  ///
  /// If this instance has no value set,
  /// then the global value of [prefixSeperator] is returned.
  String get logPrefixSeperator => _logPrefixSeperator ?? prefixSeperator;

  /// Sets the logging prefix seperator, a string prefixed to any `message`
  /// given to [log].
  set logPrefixSeperator(String v) => _logPrefixSeperator = v;

  /// A global default value that can be set via the main [drun] method,
  /// or an environment variable `DRUN_LOG_PREFIX_SEPERATOR`.
  static String prefixSeperator = ' | ';

  /// Logs the given [message] to `stdout`.
  ///
  /// Example usage:
  ///
  /// ```dart
  /// Future build() => task((drun) {
  ///   drun.log('building project...');
  /// });
  /// ```
  ///
  /// If [logBuffered] is `true` then the [message] will be stored in memory
  /// until [writeBufferedLogs()] is called, otherwise it will be output
  /// immediately.
  void log(String message) {
    if (logBuffered) {
      _logBuffer.add(message);
    } else {
      stdout.writeln('${logPrefix}${logPrefixSeperator}${message}');
    }
  }

  /// If [logBuffered] is true then all messages written by [log] will be
  /// stored in memory, this method is used to output those messages all
  /// at once.
  ///
  /// Calling this directly is considered advanced usage,
  /// this is called by [task()] if required.
  void writeBufferedLogs() {
    if (_logBuffer.isNotEmpty) {
      if (logBufferedTpl?.isNotEmpty ?? false) {
        stdout.write(
          Template(logBufferedTpl).renderString({
            'prefix': logPrefix,
            'logs': _logBuffer.join('\n'),
          }),
        );
      } else {
        stdout.writeAll(_logBuffer, '\n');
      }
    }
  }

  final _colors = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];

  final _prefixToColor = <String, int>{};

  String _colorize(String prefix, {String message}) {
    return _pen(prefix).write(message ?? prefix);
  }

  AnsiPen _pen(String prefix) {
    if (!_prefixToColor.containsKey(prefix)) {
      var availableColors = <int>[];
      var choosenColors = _prefixToColor.values;
      if (choosenColors.length >= _colors.length) {
        // We reached the maximum number of available colors so
        // we will just have to reuse a color.
        availableColors = _colors;
      } else {
        // Restrict avaliable color to ones we have not used yet
        for (var color in _colors) {
          if (!choosenColors.contains(color)) {
            availableColors.add(color);
          }
        }
      }

      // Choose a new color
      int choosen;
      if (availableColors.length == 1) {
        choosen = availableColors[0];
      } else {
        choosen = availableColors[Random().nextInt(availableColors.length)];
      }
      _prefixToColor[prefix] = choosen;
    }

    return AnsiPen()..xterm(_prefixToColor[prefix]);
  }
}
