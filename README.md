A Dart version for the 1 billion rows challange. See 1brc for more details: [1brc][]


### To create measurements files 

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
- [read_byte_by_byte.dart](solutions/read_byte_by_byte.dart) -- too slow
    - read file byte by byte
 - [read_lines_1.dart](solutions/read_lines_1.dart) -- ~410 seconds 
    - stream file as rows 
    - store stats in `List<double>`
 - [read_lines_2.dart](solutions/read_lines_2.dart) -- ~408 seconds 
    - stream file as rows 
    - store stats in `Stats` mutable object
- [read_bytes_1.dart](solutions/read_bytes_1.dart) -- ~310 seconds
    - read all bytes into memory, then loop through bytes
    - stores stats in `List<double>`
- [read_bytes_2.dart](solutions/read_bytes_2.dart) -- ~228 seconds
    - same as above but stores stats in `Float32List`
- [read_bytes_3.dart](solutions/read_bytes_3.dart) -- ~218 seconds
    - same as above but stores stats in `Stats` mutable object
- [read_bytes_async.dart](solutions/read_bytes_async.dart) -- ~205 seconds
    - split task into chunks and evaluate them asynchronously
    - each chunk reads part of the file on its own
- [read_bytes_isolates.dart](solutions/read_bytes_async.dart) -- ~47 seconds for 10 isolates and ~41 seconds for 24 isolates
    - same as above but split chunks into isolates
- [read_bytes_isolates_mmap.dart](solutions/read_bytes_async.dart) -- ~29 seconds for 10 isolates &  ~10 seconds for 24 isolates.
    - same as above but split chunks into isolates
    - by: @simolus3

### Notes:
According to the [challange][1brc], we can assume that a row may have anywhere from 6 bytes to 107 bytes such that:

- station name: 1 to 100 bytes
- semicolon: 1 byte
- temperature: 3-5 bytes from (e.g. "0.0" is 3 bytes and "-99.9" is 5 bytes)
- newline: 1 byte 

> note: generated file seem to end with a newline as well

Given that, the file size is anything between 6x10^9 (6-GB) to 107x10^9 (107-GB) but we know it's ~12GB according to the challange.

With this information, if we would like to process the data in multiple chunks across multiple isolates (let's say 10 where each processes 100 million rows), then we can add an additional 107 bytes for the the first nine isolates in case a row spans between two chunks. In other words, when we reach the end of the chunk, we continue reading until first newline appears (unless the end of the chunk happen to contain a newline). On the other hand, when we evaluate the last 9 chunks, we skip the initial bytes until the first newline appear (again, unless the previous chunk ended with a newline).


Results so far using the method above (see [solutions/read_bytes_isolates.dart](solutions/read_bytes_isolates.dart)):
```
# isolates       hr:min:sec
      8           00:00:54
     10           00:00:47
     20           00:00:45
```

Evaluated on:
```
Device: MacBook Pro (16-inch, 2019)
Processor: 2.4 GHz 8-Core Intel Core i9
Memory: 32 GB 2667 MHz DDR4
Dart SDK version: 3.2.3 (stable) 
```


<!-- Ref -->
[1brc]: https://github.com/gunnarmorling/1brc


