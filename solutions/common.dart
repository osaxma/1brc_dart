import 'dart:math';

const rows = 1 * 1000 * 1000 * 1000;
const maxBytesPerRow = 107; // see README
const semiColonCodeUnit = 59;
const newLineCodeUnit = 10;

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
