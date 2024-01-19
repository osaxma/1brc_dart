all: solutions/best.aot solutions/best_mmap.aot

solutions/best.aot: solutions/best.dart
	dart compile aot-snapshot solutions/best.dart
	dart compile jit-snapshot solutions/best.dart measurements_1b.txt

solutions/best_mmap.aot: solutions/best_mmap.dart
	dart compile aot-snapshot solutions/best_mmap.dart
	dart compile jit-snapshot solutions/best_mmap.dart measurements_1b.txt 

runaot:
	dartaotruntime solutions/best.aot measurements_1b.txt
runjit:
	dart run solutions/best.jit measurements_1b.txt

runaot_mmap:
	dartaotruntime solutions/best_mmap.aot measurements_1b.txt

# does not work for now, see: https://github.com/dart-lang/sdk/issues/54607
runjit_mmap:
	dart run solutions/best_mmap.jit measurements_1b.txt

clean:
	rm -f solutions/best.aot solutions/best_mmap.aot solutions/best.jit solutions/best_mmap.jit