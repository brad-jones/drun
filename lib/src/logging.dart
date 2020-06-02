import 'dart:math';
import 'package:ansicolor/ansicolor.dart';

/*
  Global default settings for logging.

  The reason we have these globals is due to the disconnect between our main
  `drun` function and our `task` function. For example:
  ```dart
  Future<void> main(List<String> argv) => drun(argv, logBuffered: true);

  Future<void> foobar() => task((drun) {
    drun.log('hello world'); // logBuffered = true here
  });
  ```

  To solve this we would have no option but to change the way we define our
  `Makefile.dart` files. In any case this is just a task runner and I am not
  going to get to upset about not adhearing to best practise like DI, IoC, etc...

  You could solve the globals issue like this perhaps...
  ```dart
  Future<void> main(List<String> argv) => drun(argv, {
    'foobar': (drun) => drun.log('hello world'),
  }, logBuffered: true);
  ```

  But now you have a string as the name of the task and
  then we end up doing stuff like this:
  ```dart
  Future<void> main(List<String> argv) => drun(argv, {
    'foo': (drun) => drun.log('hello from foo'),
    'bar': (drun) => drun.log('hello from bar'),
    'foobar': (drun) => drun.depends(['foo', 'bar']),
  }, logBuffered: true);
  ```

  Perhaps one way to solve the problem would be to take a leaf out of
  <https://robo.li/> book and use a class to define the `Makefile.dart`:
  ```dart
  import 'package:drun/drun.dart' as drun;
  import './projects/baz/Makefile.dart' as baz;

  Future<void> main(List<String> argv) => Makefile.main(argv, logBuffered: true);

  class Makefile extends drun.Makefile {
    void foo() {
      log('hello from foo');
    }

    void bar() {
      log('hello from bar');
    }

    void foobar() {
      foo();
      bar();
      baz.Makefile().build();
      // this sucks but otherwise I kinda like this idea
      // You could create base Makefile classes and share them between similar
      // projects. You could make make the functions static I guess.
      baz.Makefile.build();
    }
  }
  ```

  Anyway I hope my ramblings explain why these globals are here.
*/
var buffered = false;

const bufferedTplDefault =
    '>>> {{prefix}}\n--------------------------------------------------------------------------------\n';
var bufferedTpl = bufferedTplDefault;

const prefixSeperatorDefault = ' | ';
var prefixSeperator = prefixSeperatorDefault;

// Restrict avaliable colors to 16 bit to ensure best compatibility
// 256 bit terminal colors are nice but without careful choice of colors I find
// that more often than not you get output that is hard to read, sometimes it's
// pretty hard to tell the difference between a darker and lighter color.
const colors = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];

// Keep a map of color choices so we don't choose the same, at least until we
// have choosen all available colors.
var prefixToColor = <String, int>{};

/// Given a [prefix] this function will return that prefix colored with an
/// [AnsiPen] choosen by [logPen]. If [message] is provided then the message
/// will be the string that is colored in the prefix's color instead of the
/// prefix it's self.
///
/// This function is provided for cases where you want to output your own
/// custom logs using some other mechanism instead of [log] but still wish to
/// retain the correct prefix color.
String colorize(String prefix, {String message}) {
  return pen(prefix).write(message ?? prefix);
}

/// For a given [prefix] this will return a random [AnsiPen] that can be used
/// to colorize text.
///
/// This function is provided for advanced usage cases where you wish to
/// directly use an [AnsiPen] instance. Please refer to either [log] or
/// [logColorize] for normal usage.
AnsiPen pen(String prefix) {
  if (!prefixToColor.containsKey(prefix)) {
    var availableColors = <int>[];
    var choosenColors = prefixToColor.values;
    if (choosenColors.length >= colors.length) {
      // We reached the maximum number of available colors so
      // we will just have to reuse a color.
      availableColors = colors;
    } else {
      // Restrict avaliable color to ones we have not used yet
      for (var color in colors) {
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
    prefixToColor[prefix] = choosen;
  }

  return AnsiPen()..xterm(prefixToColor[prefix]);
}
