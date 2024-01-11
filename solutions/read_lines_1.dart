import 'dart:convert';
import 'dart:io';
import 'dart:math';

// took 410-seconds (~6.83 minutes)
void main(List<String> args) async {
  final filePath = args.single;

  final sw = Stopwatch()..start();

  // stream of rows
  final stream = File(filePath) //
      .openRead()
      .transform(utf8.decoder)
      .transform(LineSplitter())
      .map((line) => line.split(';'));

  // storage
  final stations = <String, List<double> /* min, max, sum, count */ >{};

  // listen to the stream and wait for the subscription as future
  await stream.listen((row) {
    final station = row.first;
    final temp = double.parse(row.last);

    if (stations[station] == null) {
      // add new station
      stations[station] = List.generate(
        4 /* length */,
        (i) => i != 3 ? temp /* min|max|sum */ : 1 /* count */,
        growable: false,
      );
    } else {
      // update existing station
      stations.update(station, (stats) {
        stats[0] = min(stats[0], temp);
        stats[1] = max(stats[1], temp);
        stats[2] = stats[2] + temp;
        stats[3] = stats[3] + 1;
        return stats;
      });
    }
  }).asFuture();

  sw.stop();

  final buff = StringBuffer();
  stations.forEach((key, value) {
    final min = value[0];
    final avg = value[2] / value[3];
    final max = value[1];
    buff.writeln('$key=$min/$avg/$max');
  });

  print(buff.toString());
  print('took ${sw.elapsed.inSeconds}-seconds');
}
