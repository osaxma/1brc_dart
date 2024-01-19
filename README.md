A Dart version for the 1 billion rows challange. See [1brc][] for more details.

### Challange TL;DR
- 1 billion rows of weather stations temperatures
- Each row looks like this encoded in utf8: 
    ```
    |   station name |   ;    |  temperature |  \n    |
    |<1 to 100-bytes>|<1-byte>|<3 to 5 bytes>|<1 byte>|
    ```
- Temperature can be anywhere from `-99.9` to `0.0` to `99.9`
- There are 413 unique stations for the main challange file 
    - though the challange says the maximum should be 10,0000 unique stations.
- **Requirement**: 
    - compute `min`, `average` and `max` for each station
    - print them 

For the best result in stand alone files, see: 
- [best.dart](/solutions/best.dart) (~10 sec)<sup>*</sup>
- or [best_mmap.dart](/solutions/best_mmap.dart) (~5 sec)<sup>*</sup>

><sup>*</sup> on my machine -- see details below

### Create Measurements Files 

> _Note: `measurements_1000.txt` is a sample data with 1000 entries that is used for dev/testing only_

You cannot evaluate the actual solutions without generating the data, and here's a quick way to do it:
- `git clone https://github.com/gunnarmorling/1brc`
- `cd 1brc`
- Before proceeding, make sure `java --version` is at least `21`
- run `./mvnw clean verify`
- run `./create_measurements.sh 1000000000`
    - note: this will create a 12GB file called `measurements.txt`
- Once generated, you can make a symbolic link of the file in the root of this dart project for easy access such as:
    ```
    ln -s /path/to/1brc/measurements.txt measurements.txt
    ```

- Then run any of the solutions listed below using: 
    ```
    dart run solutions/read_bytes_isolates.dart measurements.txt
    ```
    _For the `isolates` solutions, you define the isolates number using `dart -Disolates=10 run ....`_

### Solutions

| solution                                                               | time                            | Notes                                                         |
|------------------------------------------------------------------------|---------------------------------|-------------------------------------------------------------- |
[read_byte_by_byte.dart](solutions/read_byte_by_byte.dart)               | too slow                        | read file byte by byte                                        |
[read_lines_1.dart](solutions/read_lines_1.dart)                         | ~410s                           | stream file as rows and store stats in `List<double>`         |
[read_lines_2.dart](solutions/read_lines_2.dart)                         | ~408s                           | stream file as rows and store stats in `Stats` mutable object |
[read_bytes_1.dart](solutions/read_bytes_1.dart)                         | ~310s                           | read all bytes, loop through them & store in `List<double>`   |
[read_bytes_2.dart](solutions/read_bytes_2.dart)                         | ~228s                           | same as above but stores stats in `Float32List`               |
[read_bytes_3.dart](solutions/read_bytes_3.dart)                         | ~218s                           | same as above but stores stats in `Stats` mutable object      |
[read_bytes_async.dart](solutions/read_bytes_async.dart)                 | ~205s                           | split task into chunks and evaluate them asynchronously       |
[read_bytes_isolates.dart](solutions/read_bytes_isolates.dart)           | ~28s _(16i)_                    | same as above but split chunks into isolates                  |
[read_bytes_isolates_mmap.dart](solutions/read_bytes_isolates_mmap.dart) | ~22s _(16i)_                    | same as above but use `mmap`/`ffi`<sup>1</sup>                |
[best.dart](solutions/best.dart)                                         | ~10s _(16i)_                    | every trick I could pull so far                               |
[best_mmap.dart](solutions/best_mmap.dart)                               | ~05s _(16i)_                    | same as above + `mmap`/`ffi`<sup>1</sup>                      |
> _(16i) refers to number of isolates based on `Platform.numberOfProcessors` on my machine_
>
><sup>1</sup> credit: [@simolus3](https://github.com/simolus3)
Evaluated on:
```
Device: MacBook Pro (16-inch, 2019)
Processor: 2.4 GHz 8-Core Intel Core i9
Memory: 32 GB 2667 MHz DDR4
Dart SDK version: 3.2.3 (stable) 
```

### Notes on Chunks Approach:
According to the [challange][1brc], we can assume that a row may have anywhere from 6 bytes to 107 bytes such that:

- station name: 1 to 100 bytes
- semicolon: 1 byte
- temperature: 3-5 bytes from (e.g. "0.0" is 3 bytes and "-99.9" is 5 bytes)
- newline: 1 byte 

Given that, the file size is anything between 6x10^9 (6-GB) to 107x10^9 (107-GB) but it's ~12GB for the main file.

With this information, if we would like to process the data in chunks across multiple isolates (let's say 10 where each processes 100 million rows), then we can add an additional 107 bytes for the the first nine chunks in case a row spans to the next chunk. In other words, when we reach the end of a chunk, we continue reading bytes until we encounter a newline (unless the end of the chunk happened to contain a newline). On the other hand, when we evaluate the last 9 chunks, we read the last byte of the previous chunk to see if it's a newline. If the last chunk ended with a newline, we evaluate from the first byte, otherwise we skip the initial bytes of the chunk upto the the first newline.


<!-- Ref -->
[1brc]: https://github.com/gunnarmorling/1brc


