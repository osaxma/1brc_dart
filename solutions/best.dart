import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'dart:isolate';
import 'dart:collection';
import 'dart:typed_data';

void main(List<String> args) async {
  const isolates = int.fromEnvironment('isolates', defaultValue: 10);

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

  // see https://github.com/dart-lang/sdk/issues/54566
  // assert(bytesPerIsolate < 2 * 1000 * 1000 * 1000);

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
  // computeChunk(chunks.first.$1, chunks.first.$2, totalBytes - 1, filePath);

  final stats = await Future.wait(futures);
  final res = StationStats.mergeStats(stats);
  final buff = StringBuffer();
  res.values.forEach((d) => buff.writeln(d.toString()));
  sw.stop();
  print(buff.toString());

  print('took ${sw.elapsed} for ${res.length} stations'); // expected 413 stations
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

  // this isolate storage
  final stations = <int, StationStats>{};

  int marker = fromIndex;
  // A lot of improvements happened here by reducing implicit loops used
  double temp = 0.0;
  while (fromIndex < toIndex) {
    int stationHash = Hash.seed;
    int semicolonIndex = fromIndex + 1;
    for (;;) {
      if (bytes[semicolonIndex] == semiColonCodeUnit) {
        // we done with hashing the station name
        stationHash = Hash.finish(stationHash);
        // once we reach a semicolon, the digits can be at least 3 bytes or maximum 5 bytes
        // so the newline can be anywhere from 4 to 6 bytes after the semicolon
        marker = semicolonIndex + 1;

        // we know that the temp can be between 3 to 5 digits with one decimal point (even for 0.0)
        // such that:
        //      name             ;         temp      newline
        // |<1 to 100-bytes>|<1-byte>|<3 to 5 bytes>|<1 byte>
        // Given that, we can efficiently parse the temp for this special case than using
        // double.parse which is more generic.
        temp = 0.0;

        // check for minus sign
        double sign;
        if (bytes[marker] != minusCodeUnit) {
          sign = 1.0;
        } else {
          sign = -1.0;
          marker++;
        }
        // now we only have anything between 1 and 4 bytes left where 1 byte is the dot
        // case 1 -> X.X & case 2 -> XX.X
        // We need to convert the digits to integer
        // Simply, this is the same as: '12.3'.replaceAll('.','').reduce((a,b) => (a * 10 ) + b)
        // which gives: 123 as an integer (we divide later)
        // but without unncessary conversions.
        if (bytes[marker + 1] == dotCodeUnit) {
          temp = ((bytes[marker] - zeroCodeUnit) * 10.0) + (bytes[marker + 2] - zeroCodeUnit);
          marker = marker + 3; // i.e. newline mark
        } else {
          temp = ((bytes[marker] - zeroCodeUnit) * 10.0) + (bytes[marker + 1] - zeroCodeUnit);
          temp = (temp * 10.0) + (bytes[marker + 3] - zeroCodeUnit);
          marker = marker + 4; // i.e. newline mark
        }
        temp *= sign;

        break;
      }
      stationHash = Hash.combine(stationHash, bytes[semicolonIndex]);
      semicolonIndex++;
    }

    final stats = stations[stationHash];

    if (stats != null) {
      stats
        ..sum = stats.sum + temp
        ..maximum = max(stats.maximum, temp)
        ..minimum = min(stats.minimum, temp)
        ..count = stats.count + 1;
    } else {
      stations[stationHash] = StationStats(
        utf8.decode(Uint8List.sublistView(bytes, fromIndex, semicolonIndex)),
        stationHash,
        maximum: temp,
        minimum: temp,
        sum: temp,
        count: 1,
      );
    }

    fromIndex = marker + 1;
  }

  return stations;
}

/* -------------------------------------------------------------------------- */
/*                                  CONSTANTS                                 */
/* -------------------------------------------------------------------------- */

const rows = 1 * 1000 * 1000 * 1000;
const maxBytesPerRow = 107; // see README

// code units
const newLineCodeUnit = 10;
const minusCodeUnit = 45;
const dotCodeUnit = 46;
const zeroCodeUnit = 48;
const semiColonCodeUnit = 59;

/* -------------------------------------------------------------------------- */
/*                                   Hashing                                  */
/* -------------------------------------------------------------------------- */

// same hashing used by Object.hashAll but extracted here so we don't loop twice over the bytes
// from SystemHash (not public) at dart-sdk/lib/internal/internal.dart
class Hash {
  static int seed = identityHashCode(Object);

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
    this.maximum = 1000,
    this.minimum = -1000,
    this.sum = 0,
    this.count = 0,
  });

  double minimum;
  double maximum;
  double sum;
  double count;

  static Map<int, StationStats> mergeStats(List<Map<int, StationStats>> stations) {
    final merged = <int, StationStats>{};
    for (var station in stations) {
      for (var stat in station.entries) {
        final mergedStat = merged.putIfAbsent(stat.key, () => stat.value);
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
