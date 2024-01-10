import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'common.dart';

// took 206-seconds (~3.43-minutes)
void main() async {
  final splitBy = 6;
  final sw = Stopwatch()..start();
  final totalBytes = File(measurements1BPath).lengthSync();
  final bytesPerIsolate = totalBytes ~/ splitBy;
  final remainder = totalBytes % splitBy;

  final chunks = List.generate(splitBy, (i) {
    final start = i * bytesPerIsolate;
    final isLast = i == splitBy - 1;
    final end = (start + bytesPerIsolate) - 1 + (isLast ? remainder : 0);
    return (start, end);
  });

  final futures = <Future<Map<String, Data>>>[];
  for (var c in chunks) {
    futures.add(computeChunk(c.$1, c.$2, totalBytes - 1));
  }

  final res = await Future.wait(futures).then((data) => mergeData(data));

  final buff = StringBuffer();
  res.values.forEach((d) => buff.writeln(d.toString()));
  sw.stop();
  print(buff.toString());
  print('took ${sw.elapsed.toString()}');
}

Future<Map<String, Data>> computeChunk(int startByte, int endByte, int lastBytePos /* end of bytes */) async {
  final file = File(measurements1BPath).openSync()..setPositionSync(startByte);

  final endPadding = endByte != lastBytePos ? maxBytesPerRow : 0;
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
