import 'dart:mirrors';

dynamic typeParser(Type reflectedType, dynamic v) {
  switch (reflectedType) {
    case int:
      return int.parse(v);
    case double:
      return double.parse(v);
    default:
      if (reflectedType.toString().startsWith('List<')) {
        switch (reflectType(reflectedType).typeArguments[0].reflectedType) {
          case int:
            var list = <int>[];
            for (var value in (v as List<String>)) {
              list.add(int.parse(value));
            }
            return list;
          case double:
            var list = <double>[];
            for (var value in (v as List<String>)) {
              list.add(double.parse(value));
            }
            return list;
        }
      }
      return v;
  }
}
