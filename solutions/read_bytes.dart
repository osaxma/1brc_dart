import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'common.dart';

// took 310-seconds
void main() {
  final sw = Stopwatch()..start();
  final bytes = File(measurements1BPath).readAsBytesSync(); // this takes ~9 seconds on its own

  final city = BytesBuilder(copy: false);

  var start = 0;
  var end = 0;
  for (var b in bytes) {
    if (b == 59) {
      city.add(Uint8List.sublistView(bytes, start, end));
      end++;
      start = end;
      continue;
    } else if (b == 10) {
      addCity(
        String.fromCharCodes(city.takeBytes()),
        double.parse(String.fromCharCodes(Uint8List.sublistView(bytes, start, end))),
      );
      end++;
      start = end;
      continue;
    } else {
      end += 1;
    }
  }

  sw.stop();

  print(citiesToString());
  print('took ${sw.elapsed.inSeconds}-seconds');
}

final cities = <String, List<double> /* min, max, sum, count */ >{};
void addCity(String city, double temp) {
  // Float32List(length)
  if (cities[city] == null) {
    cities[city] = List.generate(4, (i) => i == 3 ? 1 : temp, growable: false);
  } else {
    cities.update(city, (value) {
      value[0] = min(value[0], temp);
      value[1] = max(value[1], temp);
      value[2] = value[2] + temp;
      value[3] = value[3] + 1;
      return value;
    });
  }
}

String citiesToString() {
  return cities
      .map((key, value) => MapEntry(key, List.generate(3, (i) => i != 2 ? value[i] : value[i] / value[i + 1])))
      .toString();
}
