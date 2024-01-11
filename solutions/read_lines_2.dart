import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'common.dart';

// took 406-seconds (~6.76 min)
void main(List<String> args) async {
  final filePath = args.single;
  final sw = Stopwatch()..start();
  final cities = <String, Stats>{};

  final stream = File(filePath) //
      .openRead()
      .transform(utf8.decoder)
      .transform(LineSplitter())
      .map((line) => line.split(';'));

  await stream.listen((row) {
    final name = row.first;
    final temp = double.parse(row.last);
    final data = cities.putIfAbsent(name, () => Stats(name));
    data
      ..sum = data.sum + temp
      ..maximum = max(data.maximum, temp)
      ..minimum = min(data.minimum, temp)
      ..count = data.count + 1;
  }).asFuture();

  sw.stop();

  print(Stats.dataToString(cities.values));
  print('took ${sw.elapsed.inSeconds}-seconds (${sw.elapsed.inSeconds / 60})');
}
