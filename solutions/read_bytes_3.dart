import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'common.dart';

// Stats stored as Stats mutable object

// took 218-seconds (3.6 minutes)
void main(List<String> args) {
  final filePath = args.single;

  final sw = Stopwatch()..start();
  final cities = <String, Stats>{};
  final bytes = File(filePath).readAsBytesSync(); // this takes ~9 seconds on its own

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
      final stats = cities.putIfAbsent(name, () => Stats(name));
      stats
        ..sum = stats.sum + temp
        ..maximum = max(stats.maximum, temp)
        ..minimum = min(stats.minimum, temp)
        ..count = stats.count + 1;

      end++;
      start = end;
      continue;
    } else {
      end += 1;
    }
  }

  sw.stop();

  print(Stats.dataToString(cities.values));
  print('took ${sw.elapsed.toString()}');
}
