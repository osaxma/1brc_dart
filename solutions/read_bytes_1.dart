import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'common.dart';

// Stats stored as List<double>

// took 310-seconds
void main(List<String> args) {
  final filePath = args.single;

  final sw = Stopwatch()..start();
  // read the entire file into a list of byte (i.e. ~12-GB)
  // this takes ~9 seconds on its own
  final Uint8List bytes = File(filePath).readAsBytesSync();

  // data storage
  final stations = <String, List<double> /* min, max, sum, count */ >{};

  // holds a reference to the bytes of the city until we get the temperature
  final stationContainer = BytesBuilder(copy: false);
  // markers for both station and temp bytes
  var start = 0;
  var end = 0;
  for (var byte in bytes) {
    if (byte == semiColonCodeUnit) {
      /*  reaching a semicolon means we got the station name */

      // store the city in the container to be consumed once we get the temperature
      stationContainer.add(Uint8List.sublistView(bytes, start, end));

      // increment and reset to start marking temperature
      start = ++end;
      continue;
    } else if (byte == newLineCodeUnit) {
      // reaching a newline means we got the temperature
      // so now we can parse the bytes and store them

      final station = String.fromCharCodes(
        stationContainer.takeBytes(),
      );

      final temp = double.parse(
        String.fromCharCodes(Uint8List.sublistView(bytes, start, end)),
      );

      if (stations[station] == null) {
        // add new station
        stations[station] = List.generate(
          4 /* length */,
          (i) => i != 3 ? temp /* min|max|sum */ : 1 /* count */,
          growable: false,
        );
      } else {
        // update existing station
        stations.update(station, (stats) {
          stats[0] = min(stats[0], temp);
          stats[1] = max(stats[1], temp);
          stats[2] = stats[2] + temp;
          stats[3] = stats[3] + 1;
          return stats;
        });
      }

      // increment and reset to start marking next station name
      start = ++end;
      continue;
    } else {
      end++;
    }
  }

  sw.stop();

  print(citiesToString(stations));
  print('took ${sw.elapsed.inSeconds}-seconds');
}

String citiesToString(Map<String, List<double>> cities) {
  return cities
      .map((key, value) => MapEntry(key, List.generate(3, (i) => i != 2 ? value[i] : value[i] / value[i + 1])))
      .toString();
}
