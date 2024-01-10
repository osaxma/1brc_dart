import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'common.dart';

// took 410-seconds (~6.83 minutes)
void main() async {
  final sw = Stopwatch()..start();
  final file = File(measurements1000Path).openRead().transform(utf8.decoder).transform(LineSplitter());

  final sub = file.listen((event) {
    final s = event.split(';');

    final temp = double.parse(s.last);

    if (cities[s.first] == null) {
      cities[s.first] = List.generate(4, (i) => i == 3 ? 1 : temp, growable: false);
    } else {
      cities.update(s.first, (value) {
        value[0] = min(value[0], temp);
        value[1] = max(value[1], temp);
        value[2] = value[2] + temp;
        value[3] = value[3] + 1;
        return value;
      });
    }
  });

  await sub.asFuture();
  sw.stop();

  final buff = StringBuffer();
  cities.forEach((key, value) {
    final min = value[0];
    final avg = value[2] / value[3];
    final max = value[1];
    buff.writeln('$key=$min/$avg/$max}');
  });

  print(buff.toString());
  print('took ${sw.elapsed.inSeconds}-seconds');
}

final cities = <String, List<double> /* min, max, sum, count */ >{};
