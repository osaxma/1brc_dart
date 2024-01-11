// Credit: Simon Binder
// url: https://gist.github.com/simolus3/0ae5a63d6bf499c53aeb7b75701d8f5e
import 'dart:collection';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:ffi/ffi.dart';

import 'common.dart';

@Native<Pointer<Void> Function(Pointer<Void>, Size, Int, Int, Int, Size)>()
external Pointer<Void> mmap(Pointer<Void> addr, int length, int prot, int flags, int fd, int offset);

@Native<Int Function(Pointer<Utf8>, Int)>()
external int open(Pointer<Utf8> path, int mode);

void main(List<String> args) async {
  const isolates = int.fromEnvironment('isolates', defaultValue: 24);

  final String filePath = args.single;

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

  final fd = open(filePath.toNativeUtf8(), 0);
  if (fd < 0) {
    throw 'open';
  }

  final ptr = mmap(nullptr, totalBytes, 1 /*PROT_READ*/, 2 /* MAP_PRIVATE */, fd, 0);
  if (ptr.address == 0) {
    throw 'mmap';
  }

  final futures = <Future<Map<String, Stats>>>[];
  for (var c in chunks) {
    final address = ptr.address;

    futures.add(Isolate.run(
      () {
        return computeChunk(c.$1, c.$2, totalBytes - 1, address);
      },
    ));
  }

  final res = await Future.wait(futures).then((stats) => Stats.mergeStats(stats));

  final buff = StringBuffer();
  res.values.forEach((d) => buff.writeln(d.toString()));

  sw.stop();
  print(buff.toString());
  print('took ${sw.elapsed}');
}

Future<Map<String, Stats>> computeChunk(int startByte, int endByte, int fileLength, int baseAddress) async {
  // for last nine chunks, start from the end of the last chunk
  // to know if it ended with a newline
  if (startByte != 0) {
    startByte--;
  }

  final endPadding = endByte != fileLength ? maxBytesPerRow : 0;
  final length = (endByte - startByte);

  final bytes = Pointer<Uint8>.fromAddress(baseAddress).elementAt(startByte).asTypedList(length);

  var fromIndex = 0;
  var toIndex = length;

  // effective start
  if (startByte != 0) {
    fromIndex = bytes.indexOf(newLineCodeUnit, 0) + 1;
  }

  // effective end
  if (endPadding != 0) {
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
