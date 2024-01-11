import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'common.dart';

//   # isolates       hr:min:sec
//         8           00:00:31
//        10           00:00:33
//        24           00:00:29
void main(List<String> args) async {
  const isolates = int.fromEnvironment('isolates', defaultValue: 10);

  final filePath = args.single;

  final sw = Stopwatch()..start();

  final totalBytes = File(filePath).lengthSync();
  final bytesPerIsolate = totalBytes ~/ isolates;
  final remainder = totalBytes % isolates;

  final chunks = List.generate(isolates, (i) {
    final start = i * bytesPerIsolate;
    final isLast = i == isolates - 1;
    final end = (start + bytesPerIsolate) - 1 + (isLast ? remainder : 0);
    return (start, end);
  });

  // see https://github.com/dart-lang/sdk/issues/54566
  assert(bytesPerIsolate < 2 * 1000 * 1000);

  final futures = <Future<Map<String, Stats>>>[];
  for (var chunk in chunks) {
    futures.add(Isolate.run(() => computeChunk(chunk.$1, chunk.$2, totalBytes - 1, filePath)));
  }

  final res = await Future.wait(futures).then((stats) => Stats.mergeStats(stats));

  final buff = StringBuffer();
  res.values.forEach((d) => buff.writeln(d.toString()));

  sw.stop();
  print(buff.toString());
  print('took ${sw.elapsed}');
}

Future<Map<String, Stats>> computeChunk(int startByte, int endByte, int fileLength, String filePath) async {
  // for last nine chunks, start from the end of the last chunk
  // to know if it ended with a newline
  if (startByte != 0) {
    startByte--;
  }

  final file = File(filePath).openSync()..setPositionSync(startByte);

  // for the first nine chunks, add 107 bytes
  // in case a row spans from this chunk to the next
  final endPadding = endByte != fileLength ? maxBytesPerRow : 0;
  final length = (endByte - startByte);

  final bytes = Uint8List(length + endPadding);

  file.readIntoSync(bytes);

  var fromIndex = 0;
  var toIndex = length;

  if (startByte != 0) {
    // effective start
    fromIndex = bytes.indexOf(newLineCodeUnit, 0) + 1;
  }

  if (endPadding != 0) {
    // effective end
    toIndex = bytes.indexOf(newLineCodeUnit, length);
  }

  // this isolate storage
  final stations = HashMap<String, Stats>();

  int marker = fromIndex;
  int stationStart = marker;
  int stationEnd = 0;
  int tempStart = 0;
  for (fromIndex; fromIndex < toIndex; fromIndex++) {
    final b = bytes[fromIndex];
    if (b == semiColonCodeUnit) {
      stationEnd = marker;
      tempStart = ++marker;
      continue;
    } else if (b == newLineCodeUnit) {
      final name = String.fromCharCodes(bytes, stationStart, stationEnd);
      final temp = double.parse(String.fromCharCodes(bytes, tempStart, marker));

      final stats = stations[name] ??= Stats(name);
      stats
        ..sum = stats.sum + temp
        ..maximum = max(stats.maximum, temp)
        ..minimum = min(stats.minimum, temp)
        ..count = stats.count + 1;

      // start new row
      stationStart = ++marker;
      continue;
    } else {
      marker++;
    }
  }

  return stations;
}
