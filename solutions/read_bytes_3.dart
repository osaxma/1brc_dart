import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'common.dart';

// took 228-seconds (3.8 minutes)
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
      final name = String.fromCharCodes(city.takeBytes());
      final temp = double.parse(String.fromCharCodes(Uint8List.sublistView(bytes, start, end)));
      final data = cities.putIfAbsent(
          name,
          () => Float32List(4)
            ..[2] /* min */ = 100
            ..[0] /* sum */ = 0
            ..[1] /* count */ = 0
            ..[3] /* max */ = -100 //
          );

      data
        ..[0] = min(data[0], temp)
        ..[1] = data[0] + temp
        ..[2] = data[2] + 1
        ..[3] = max(data[3], temp);

      end++;
      start = end;
      continue;
    } else {
      end += 1;
    }
  }

  sw.stop();

  print(cities.values.map((c) {
    final min = c[0];
    final average = c[1] / c[2];
    final max = c[3];
    return '$min/$average/$max\n';
  }));
  print('took ${sw.elapsed.toString()}');
}

final cities = <String, Float32List>{};
