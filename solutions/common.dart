import 'dart:math';

const rows = 1 * 1000 * 1000 * 1000;
const maxBytesPerRow = 107; // see README
const semiColonCodeUnit = 59;
const newLineCodeUnit = 10;

const measurements1BPath = 'measurements_1b.txt';
// for quick testing
const measurements1000Path = 'measurements_1000.txt';

class Data {
  final String name;
  double sum = 0;
  double count = 0;
  double minimum = double.infinity;
  double maximum = double.negativeInfinity;
  double get average => sum / count;

  Data(this.name);

  void merge(Data data) {
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

  static String dataToString(Iterable<Data> data) {
    final buff = StringBuffer();
    data.forEach((d) => buff.writeln(d.toString()));
    return buff.toString();
  }
}
