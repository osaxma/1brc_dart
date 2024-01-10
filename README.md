A Dart version for the 1 billion rows challange. See 1brc for more details: [1brc][]


### To create measurements files 
You cannot run this code without generating the data, and here's a quick way to do it:
- `git clone https://github.com/gunnarmorling/1brc`
- `cd 1brc`
- Before proceeding, make sure `java --version` is 21
- `./mvnw clean verify`
- `./create_measurements.sh 1000000000`
    - note this will create a 12GB file called `measurements_1B.txt`

Once generated, just make a symbolic link of it in the root of this project (i.e. `ln -s /path/to/1brc/measurements_1b.txt measurements_1b.txt`). 


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


