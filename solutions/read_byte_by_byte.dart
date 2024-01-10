import 'dart:io';
import 'dart:math';

import 'common.dart';

// toooooo slow i didn't bother waiting
void main() {
  final sw = Stopwatch()..start();

  final f = File(measurements1BPath).openSync();
  int byte;
  var city = <int>[];
  var temp = <int>[];
  var state = 0; // 0 city | 1 number | 2 new line
  for (;;) {
    byte = f.readByteSync();
    if (byte == -1) {
      break;
    }
    if (byte == newLineCodeUnit) {
      state = 0;
      addCity(city, temp);
      city.clear();
      temp.clear();
    } else if (byte == semiColonCodeUnit) {
      state = 1;
    } else {
      if (state == 0) {
        city.add(byte);
      } else {
        temp.add(byte);
      }
    }
  }
  sw.stop();
  print(cities.toString());
  print('took ${sw.elapsed.inSeconds}-seconds');
}

final cities = <String, List<double> /* min, max, sum, count */ >{};
void addCity(List<int> city, List<int> temp) {
  final cityS = String.fromCharCodes(city);
  final tempD = double.parse(String.fromCharCodes(temp));
  if (cities[cityS] == null) {
    cities[cityS] = List.generate(4, (i) => i == 3 ? 1 : tempD, growable: false);
  } else {
    cities.update(cityS, (value) {
      value[0] = min(value[0], tempD);
      value[1] = max(value[1], tempD);
      value[2] = value[2] + tempD;
      value[3] = value[3] + 1;
      return value;
    });
  }
}
