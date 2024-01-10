import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'common.dart';

//   # isolates       hr:min:sec
//         8           00:00:54
//        10           00:00:47
//        20           00:00:45
void main() async {
  final isolates = 10;
  final String filePath;
  if (!File(measurements1BPath).existsSync()) {
    print('measurements_1b.txt does not exists -- will use sample file of 1000 entries');
    filePath = measurements1000Path;
  } else {
    filePath = measurements1BPath;
  }

  final sw = Stopwatch()..start();
  final totalBytes = File(filePath).lengthSync();
  final bytesPerIsolate = totalBytes ~/ isolates;
  final remainder = totalBytes % isolates;

  // see https://github.com/dart-lang/sdk/issues/54566
  assert(bytesPerIsolate < 2 * 1000 * 1000);

  final chunks = List.generate(isolates, (i) {
    final start = i * bytesPerIsolate;
    final isLast = i == isolates - 1;
    final end = (start + bytesPerIsolate) - 1 + (isLast ? remainder : 0);
    return (start, end);
  });

  final futures = <Future<Map<String, Data>>>[];
  for (var c in chunks) {
    futures.add(Isolate.run(
      () {
        return computeChunk(c.$1, c.$2, totalBytes - 1, filePath);
      },
    ));
  }

  final res = await Future.wait(futures).then((data) => mergeData(data));

  final buff = StringBuffer();
  res.values.forEach((d) => buff.writeln(d.toString()));

  sw.stop();
  print(buff.toString());
  print('took ${sw.elapsed}');
}

Future<Map<String, Data>> computeChunk(int startByte, int endByte, int fileLength, String path) async {
  final file = File(path).openSync()..setPositionSync(startByte);

  final endPadding = endByte != fileLength ? maxBytesPerRow : 0;
  final length = (endByte - startByte);

  final bytes = Uint8List(length + endPadding);

  file.readIntoSync(bytes);

  var fromIndex = 0;
  var toIndex = length;

  // effective start
  if (startByte != 0) {
    fromIndex = bytes.indexOf(newLineCodeUnit) + 1;
  }

  // effective end
  if (endPadding != 0) {
    for (var i = length; i < bytes.length; i++) {
      if (bytes[i] == newLineCodeUnit) {
        toIndex = i + 1;
        break;
      }
    }
  }

  final cities = <String, Data>{};

  final city = BytesBuilder(copy: false);

  var start = fromIndex;
  var end = fromIndex;
  int b = 0;

  for (fromIndex; fromIndex < toIndex; fromIndex++) {
    b = bytes[fromIndex];
    if (b == semiColonCodeUnit) {
      city.add(Uint8List.sublistView(bytes, start, end));
      end++;
      start = end;
      continue;
    } else if (b == newLineCodeUnit) {
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

  return cities;
}

Map<String, Data> mergeData(List<Map<String, Data>> data) {
  final merged = <String, Data>{};
  for (var d in data) {
    for (var entry in d.entries) {
      final d = merged.putIfAbsent(entry.key, () => Data(entry.key));
      d.merge(entry.value);
    }
  }
  return merged;
}
