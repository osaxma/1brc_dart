import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'common.dart';

// took 406-seconds (~6.76 min)
void main() async {
  final sw = Stopwatch()..start();
  final cities = <String, Data>{};
  final bytes =
      File(measurements1000Path).openRead().transform(utf8.decoder).transform(LineSplitter()).map((l) => l.split(';'));
  await bytes.listen((line) {
    final name = line[0];
    final temp = double.parse(line[1]);
    final data = cities.putIfAbsent(name, () => Data(name));
    data
      ..sum = data.sum + temp
      ..maximum = max(data.maximum, temp)
      ..minimum = min(data.minimum, temp)
      ..count = data.count + 1;
  }).asFuture();

  sw.stop();

  print(Data.dataToString(cities.values));
  print('took ${sw.elapsed.inSeconds}-seconds (${sw.elapsed.inSeconds / 60})');
}
