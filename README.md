Dart version for the 1 billion rows challange.

See 1brc for more details: [1brc][]

### Creating measurements 
- `git clone https://github.com/gunnarmorling/1brc`
- `cd 1brc`
- Before proceeding, make sure `java --version` is 21
- `./mvnw clean verify`
- `./create_measurements.sh 1000000000`
    - note this will create a 12GB file called `measurements_1B.txt`



## Notes:
According to the [challange][1brc], we can assume that a row may have anything from 6 bytes to 107 bytes such that:

- station name: 1 to 100 bytes
- semicolon: 1 byte
- temperature: 3-5 bytes from (e.g. "0.0" is 3 bytes and "-99.9" is 5 bytes)
- newline: 1 byte 

> the generated file seem to end with a newline as well


Given that, the file size is anything between 6x10^9 (6-GB) to 107x10^9 (107-GB) but we know it's ~12GB according to the challange.

With this information, if we would like to split the task across multiple isolates (let's say 10 where each processes 100 million rows), then we can add a padding of 107 bytes for the the first nine isolates in case they end at the beginning or mid of a row so they consume the rest. 

Similarly, the last 9 isolate, if they are mid row, they should move to the first `\n`



<!-- Ref -->
[1brc]: https://github.com/gunnarmorling/1brc