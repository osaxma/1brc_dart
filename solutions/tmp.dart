void main() {
  final zeroCodeUnit = 45;
  final sign = -1;
  double temp = '12.3'
      .replaceAll('.', '')
      .codeUnits
      .map((e) => e - zeroCodeUnit)
      .reduce((a, b) => (a * 10) + b)
      .toDouble();
  temp = sign * temp / 10;
}
