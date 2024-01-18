import 'dart:math';
import 'dart:typed_data';

const rows = 1 * 1000 * 1000 * 1000;
const maxBytesPerRow = 107; // see README
const semiColonCodeUnit = 59;
const newLineCodeUnit = 10;

const minusCodeUnit = 45;
const dotCodeUnit = 46;
const zeroCodeUnit = 48;

/// Converts a codeUnit for a number to a number.
///
/// Value must be between 48 and 57 as the code units for 0 and 9 are 48 and 57 respectively.
/// i.e. 57-48 = 9; 48-48 = 0; 53-48 = 5; and so on..
int codeUnitToNumber(int codeUnit) => codeUnit - zeroCodeUnit;

/// Parses a double from code units for any value between -99.9 and 99.9 (single decimal point)
/// This is specific to this challange since all values are known to be within this limit.
///
// Using `parseDoubleFromCodeUnits(List<int> codeUnits) where codeUnits is a sublist or Uint8List.sublistView
// chopped off 4+ seconds.
//
// Using parseDoubleFromCodeUnits(Uint8List codeUnits, int start), where we pass a reference to the list with
// the start index, chopped another 4+ seconds
double parseDoubleFromCodeUnits(Uint8List codeUnits, int start) {
  var number = 0.0;
  double sign = 1.0;

  if (codeUnits[start] == minusCodeUnit) {
    sign = -1;
    start++;
  }
  if (codeUnits[start + 1] == dotCodeUnit) {
    number = (codeUnitToNumber(codeUnits[start]) * 10.0) + codeUnitToNumber(codeUnits[start + 2]);
  } else {
    number = (codeUnitToNumber(codeUnits[start]) * 10.0) + codeUnitToNumber(codeUnits[start + 1]);
    number = (number * 10.0) + codeUnitToNumber(codeUnits[start + 3]);
  }
  return (number / 10.0) * sign;
}

class Stats {
  final String name;
  double minimum = double.infinity;
  double maximum = double.negativeInfinity;
  double sum = 0;
  double count = 0;
  double get average => sum / count;

  Stats(this.name);

  void merge(Stats data) {
    assert(data.name == name);
    sum = data.sum + sum;
    maximum = max(data.maximum, maximum);
    minimum = min(data.minimum, minimum);
    count = data.count + count;
  }

  @override
  String toString() {
    return '$name=$minimum/$average/$maximum';
  }

  static String dataToString(Iterable<Stats> data) {
    final buff = StringBuffer();
    data.forEach((d) => buff.writeln(d.toString()));
    return buff.toString();
  }

  static Map<String, Stats> mergeStats(List<Map<String, Stats>> stations) {
    final merged = <String, Stats>{};
    for (var station in stations) {
      for (var stat in station.entries) {
        final mergedStat = merged.putIfAbsent(stat.key, () => Stats(stat.key));
        mergedStat.merge(stat.value);
      }
    }
    return merged;
  }
}
