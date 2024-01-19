import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'dart:isolate';
import 'dart:collection';
import 'dart:typed_data';

void main(List<String> args) async {
  const isolatesFromEnv = int.fromEnvironment('isolates', defaultValue: -1);
  final isolates = isolatesFromEnv != -1 ? isolatesFromEnv : Platform.numberOfProcessors;

  final filePath = args.firstOrNull ?? 'measurements_1b.txt';

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

  assert(
    bytesPerIsolate < 2 * 1000 * 1000 * 1000,
    // see https://github.com/dart-lang/sdk/issues/54566
    'RandomAccessFile.openSync cannot read more than 2-GBs',
  );

  final futures = <Future<Map<int, StationStats>>>[];

  var i = 1;
  for (var chunk in chunks.skip(0)) {
    futures.add(
      Isolate.run(
        () => computeChunk(chunk.$1, chunk.$2, totalBytes - 1, filePath),
        debugName: 'Isolate#${i++}',
      ),
    );
  }

  final stats = await Future.wait(futures);
  final res = StationStats.mergeStats(stats);
  final buff = StringBuffer();
  res.values.forEach((d) => buff.writeln(d.toString()));
  sw.stop();
  print(buff.toString());

  final count = res.length;

  // TODO: make sure this issue doesn't occur
  // For the main challange entry, we have 413 unique stations
  // There's a second entry that's for 10k unique stations.
  if (count != 413 && count != 10 * 1000) {
    // it did happen few times
    print('Bad result, we had a hash collision');
  }

  print('took ${sw.elapsed} for $count stations');
}

Map<int, StationStats> computeChunk(int startByte, int endByte, int fileLength, String filePath) {
  // for last nine chunks, start from the end of the last chunk
  // to know if it ended with a newline
  if (startByte != 0) {
    startByte--;
  }

  // for the first nine chunks, add 107 bytes
  // in case a row spans from this chunk to the next
  final endPadding = endByte != fileLength ? maxBytesPerRow : 0;
  final length = (endByte - startByte);

  final bytes = Uint8List(length + endPadding + 1);

  final file = File(filePath).openSync()..setPositionSync(startByte);
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
  // This isolate storage
  final stations = HashMap<int, StationStats>();

  // Main loop
  //
  // Since we are looping through the bytes anyway, we collect all possible information at once.
  // Doing so, we avoid additional loops such that of `bytes.indexOf` inside the loop.
  // This approach helped reducing the time significantly.
  //
  // In this loop, we are processing the following row format for reference:
  //      name             ;         temp      newline
  // |<1 to 100-bytes>|<1-byte>|<3 to 5 bytes>|<1 byte>
  //
  // The loop does the following for each row:
  // - Collect station name's hash and start/end indices.
  // - Parse its temperature
  // - Add the stats to the stations' hash map or update existing one.
  // - Repeat.
  while (fromIndex < toIndex) {
    int stationHash = Hash.hashSeed;
    int semicolonIndex = fromIndex;
    // collect the station name index and hash from beginning to semicolon
    for (;;) {
      final b = bytes[semicolonIndex];
      stationHash = Hash.combine(stationHash, b);
      if (b == semiColonCodeUnit) break;
      semicolonIndex++;
    }
    stationHash = Hash.finish(stationHash);

    // once we reach a semicolon, we mark the start of the temperature
    int marker = semicolonIndex + 1;

    // We know that the temp can be between at least 3-digits/bytes and at most 5-digits/bytes.
    // Also we know that each temperature has one decimal point (including 0.0)
    //
    // Given that, we can efficiently parse the temp for this special case than using `double.parse`
    int temp = 0;

    // First, check for minus sign
    int sign;
    if (bytes[marker] != minusCodeUnit) {
      sign = 1;
    } else {
      sign = -1;
      marker++;
    }

    // At this point, we are left with two possible cases: "X.X" or "XX.X"
    //
    // To convert the bytes (code units) to an integer or a double, we are effictively doing:
    // ```dart
    // double temp = '12.3'
    //     .replaceAll('.', '')
    //     .codeUnits
    //     .map((unit) => unit - zeroCodeUnit)
    //     .reduce((a, b) => (a * 10) + b)
    //     .toDouble();
    // temp = sign * temp / 10; // result: 12.3 as double
    // ```
    // ... but much more directly without unnecessary conversions.
    if (bytes[marker + 1] == dotCodeUnit) {
      final d0 = bytes[marker] - zeroCodeUnit; // before dot
      marker += 2;
      final d1 = bytes[marker] - zeroCodeUnit; // after dot
      temp = 10 * d0 + d1;
    } else {
      final d0 = bytes[marker]; // first digit
      marker += 1;
      final d1 = bytes[marker]; // digit before dot
      marker += 2;
      final d2 = bytes[marker]; // digit after dot
      // two steps factored into one
      temp = (100 * d0) + (10 * d1) + d2 - (111 * zeroCodeUnit);
    }
    // we divide later at the printing stage to avoid division and int.toDouble conversion
    temp *= sign;

    // Hottest spot when looking at the CPU profiler.
    final stats = stations[stationHash];

    if (stats != null) {
      stats
        ..sum = stats.sum + temp
        ..maximum = max(stats.maximum, temp)
        ..minimum = min(stats.minimum, temp)
        ..count = stats.count + 1;
    } else {
      stations[stationHash] = StationStats(
        utf8.decode(bytes.sublist(fromIndex, semicolonIndex)),
        stationHash,
        maximum: temp,
        minimum: temp,
        sum: temp,
        count: 1,
      );
    }

    // skip the newline and increment to the begining of the next row
    fromIndex = marker + 2;
  }

  return stations;
}

/* -------------------------------------------------------------------------- */
/*                                  CONSTANTS                                 */
/* -------------------------------------------------------------------------- */
const maxBytesPerRow = 107; // see README
const newLineCodeUnit = 10;
const minusCodeUnit = 45;
const dotCodeUnit = 46;
const zeroCodeUnit = 48;
const semiColonCodeUnit = 59;

// from SystemHash (not public) at: lib/internal/internal.dart

class Hash {
  static int hashSeed = identityHashCode(Object);
  static int combine(int hash, int value) {
    hash = 0x1fffffff & (hash + value);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/* -------------------------------------------------------------------------- */
/*                                    MODEL                                   */
/* -------------------------------------------------------------------------- */

class StationStats {
  // utf8
  final String name;
  final int hash;

  StationStats(
    this.name,
    this.hash, {
    this.minimum = 1000,
    this.maximum = -1000,
    this.sum = 0,
    this.count = 0,
  });

  int minimum;
  int maximum;
  int sum;
  int count;

  static Map<int, StationStats> mergeStats(List<Map<int, StationStats>> stations) {
    final merged = <int, StationStats>{};
    for (var station in stations) {
      for (var stat in station.entries) {
        final mergedStat = merged.putIfAbsent(
          stat.key,
          () => StationStats(stat.value.name, stat.value.hash),
        );
        mergedStat
          ..maximum = max(mergedStat.maximum, stat.value.maximum)
          ..minimum = min(mergedStat.minimum, stat.value.minimum)
          ..sum += stat.value.sum
          ..count += stat.value.count;
      }
    }
    return merged;
  }

  @override
  String toString() {
    final min = (minimum / 10.0).toStringAsFixed(1);
    final avg = (sum / (count * 10.0)).toStringAsFixed(1);
    final max = (maximum / 10.0).toStringAsFixed(1);
    return '$name=$min/$avg/$max';
  }

  @override
  int get hashCode => hash;

  @override
  bool operator ==(covariant StationStats other) {
    return name == other.name;
  }
}
