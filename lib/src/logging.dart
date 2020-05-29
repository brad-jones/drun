var buffered = false;

const bufferedTplDefault =
    '>>> {{prefix}}\n--------------------------------------------------------------------------------\n';
var bufferedTpl = bufferedTplDefault;

const prefixSeperatorDefault = ' | ';
var prefixSeperator = prefixSeperatorDefault;

var settings = <String, Settings>{};

var buffers = <String, List<String>>{};

// Restrict avaliable colors to 16 bit to ensure best compatibility
// 256 bit terminal colors are nice but without careful choice of colors I find
// that more often than not you get output that is hard to read, sometimes it's
// pretty hard to tell the difference between a darker and lighter color.
const colors = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];

// Keep a map of color choices so we don't choose the same, at least until we
// have choosen all available colors.
var prefixToColor = <String, int>{};

class Settings {
  final String prefix;
  final String prefixSeperator;
  final bool buffered;
  const Settings(this.prefix, this.prefixSeperator, this.buffered);
}
