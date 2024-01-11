import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'common.dart';

// Stats stored as Float32List

// took 228-seconds (3.8 minutes)
void main(List<String> args) {
  final filePath = args.single;
  final sw = Stopwatch()..start();
  final bytes = File(filePath).readAsBytesSync(); // this takes ~9 seconds on its own

  final station = BytesBuilder(copy: false);

  var start = 0;
  var end = 0;
  for (var b in bytes) {
    if (b == semiColonCodeUnit) {
      station.add(Uint8List.sublistView(bytes, start, end));

      start = ++end;
      continue;
    } else if (b == newLineCodeUnit) {
      final name = String.fromCharCodes(station.takeBytes());
      final temp = double.parse(String.fromCharCodes(Uint8List.sublistView(bytes, start, end)));
      // add empty stats if this is a new station
      final stats = stations.putIfAbsent(
        name,
        () => Float32List(4)
          ..[0] /* min */ = 100 // upper limit
          ..[1] /* max */ = -100 // lower limit
          ..[2] /* sum */ = 0
          ..[3] /* count */ = 0,
      );

      // update the stats (new or existing)
      stats
        ..[0] = min(stats[0], temp)
        ..[1] = max(stats[1], temp)
        ..[2] = stats[2] + temp
        ..[3] = stats[3] + 1;

      start = ++end;
      continue;
    } else {
      end += 1;
    }
  }

  sw.stop();

  print(stations.values.map((c) {
    final min = c[0];
    final average = c[2] / c[3];
    final max = c[1];
    return '$min/$average/$max\n';
  }));
  print('took ${sw.elapsed.toString()}');
}

final stations = <String, Float32List>{};
