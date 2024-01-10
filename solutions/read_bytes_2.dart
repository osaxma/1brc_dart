import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'common.dart';

// took 218-seconds (3.6 minutes)
void main() {
  final sw = Stopwatch()..start();
  final cities = <String, Data>{};
  final bytes = File(measurements1000Path).readAsBytesSync(); // this takes ~9 seconds on its own

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
      final name = String.fromCharCodes(city.takeBytes());
      final temp = double.parse(String.fromCharCodes(Uint8List.sublistView(bytes, start, end)));
      final data = cities.putIfAbsent(name, () => Data(name));
      data
        ..sum = data.sum + temp
        ..maximum = max(data.maximum, temp)
        ..minimum = min(data.minimum, temp)
        ..count = data.count + 1;

      end++;
      start = end;
      continue;
    } else {
      end += 1;
    }
  }

  sw.stop();

  print(Data.dataToString(cities.values));
  print('took ${sw.elapsed.toString()}');
}
