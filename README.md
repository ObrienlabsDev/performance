# Abstract
This article attempts to systematically determine the optimized spot where we can push our hardware to the fullest possible use.
Multithreaded optimization depends on multiple factors including CPU/GPU type (M4Max vs 14900 or MetalCUDA.  Operations involving space-time tradeoffs like heap usage need to be fine tuned around batch sizes.

# Architecture
The 3n+1, collatz or hailstone numbers problem - https://en.wikipedia.org/wiki/Collatz_conjecture
- Path/Delay - http://www.ericr.nl/wondrous/delrecs.html
- Maximums - http://www.ericr.nl/wondrous/pathrecs.html
## Optimizations
  The focus here is on the base algorithm which is independent of the programming language used.  However, there are 'architecture aware' optimizations that we will detail as we get closer to the hardware using AVX, CUDA or Metal.
### Optimization 1: Skip even numbers
#### option 3: Java 8 lambda/streams parallelization
see https://github.com/ObrienlabsDev/performance/issues/19
```
public void searchCollatzParallel(long oddSearchCurrent, long secondsStart) {
	long batchBits = 5; // adjust this based on the chip architecture 
	long searchBits = 32;
	long batches = 1 << batchBits;
	long threadBits = searchBits - batchBits;
	long threads = 1 << threadBits;
		
	for (long part = 0; part < (batches + 1) ; part++) {	
		// generate a limited collection for the search space - 32 is a good
		System.out.println("Searching: " + searchBits + " space, batch " + part + " of " 
				+ batches + " with " + threadBits +" bits of " + threads + " threads"  );
		
		List<Long> oddNumbers = LongStream
				.range(1L + (part * threads), ((1 + part) * threads) - 1)
				.filter(x -> x % 2 != 0) // TODO: find a way to avoid this filter using range above
				.boxed()
				.collect(Collectors.toList());
			
		List<Long> results = oddNumbers
			.parallelStream()
			.filter(num -> isCollatzMax(num.longValue(), secondsStart))
			.collect(Collectors.toList());

		results.stream().sorted().forEach(x -> System.out.println(x));
	}
	System.out.println("last number: " + ((1 + (batches) * threads) - 1));
}
```

### Optimization 2: Combine odd/even steps
The following optimization will speed up a run by up to 21%

When we have an odd number, the next step is usually 3n + 1 applied to the current value.  However, the number resulting from 3n + 1 will always be positive - which will require at least one divide by 2.  If we combine the double step optimization with the fact that a shift right (or divide by 2) is always floor truncated (where the 1/2 is removed on an odd number).  If we combine the floor with an implicit round up (ceil) by adding 1 (where for example 27 /2  = 13.5 = 13 rounded, with + 1 = 14) - we have the following math...

(3n + 1) / 2 = 3/2 * n + 1/2, where we drop the 1/2 due to rounding on a shift right.  We then have 3/2 * n which is also n + n/2.  We add 1 to this to get a round up (it will hold as we only perform this round up for odd numbers) - of - 1 + n + n/2.

The operation...
```
3n + 1 = n << 1 + n + 1
with a subsequent
n / 2 = n >> 1
```

can be expressed as a single shift right with a add + 1 or effectively a divide by 
```
n / 2 + n + 1 = n >> 1 + n + 1
```
### Optimization 3: Roll up all divide by 2 sequences
When whe have for example a power of 2 like 256 - this will represent a straight path to 1 via 8 shift right operations.

### Optimization 4: Concurrent Multithreading - Parallel Processing
In general with 8-12 performance cores per chip - parallelization at the CPU level is 5.1 times faster than single threaded CPU code.
In general with 5120 to 32768 CUDA cores - parallelization at the GPU level is TBD times faster than parallel CPU code and TBD times faster than single threaded CPU code.
Performance will vary widely up to 10x based on the algorithm and memory/heap architecture used.  For example Java BigInteger is 5 to 50x slower than Java native long code depending on the CPU P/E core ratio, ram size and CPU type (Apple Silicon ARM64 is more efficient with BigInteger usage than IA64 Intel architectures for a reason that I am determining)

- We will use concurrency as each operation is independent of parallel searches.  Except for the case of global maximum records.  Since the code is concurrent - not all the maximums will be displayed.  The reason is the global maximum may be reached in an adjacent thread.  For example 27:111:9232 may be missed by 34177:187:1302532.  Use of Thread local maximums will solve this.
- see https://github.com/ObrienlabsDev/performance/issues/26
- 
# Performance Numbers

## Criteria
- CON: Single / Multi threaded (both CPU and GPU (you can use just 1 ALU core in a GPU)
- PRU: CPU / GPU
- FRM: native / framework (as in java long (64 bit max) or java BigInteger (open ended))
- BIT: 64 / 128 / 256 bit
- LAN: language (C, Swift, Go, Java, Python, Rust)
- ARC: Architecture (IA64/AMD64 or ARM64 - or agnostic (JIT compiled Go))
- 

## GPU

## CPU
### Multi Threaded : 32 bit run
#### 128 bit native
##### Java 
- 114 sec Macbook 16 M4max 12p4e - 13 batch
- 153 sec MacMini M4pro 8p4e 24g - 13 batch
- 225 sec MacBook 16 M1max 8p2e 32g - 13 batch
- 313 sec P1Gen6 13800H 6p8e/20t 2.5/4.1 GHz 64g - 13 batch
- 394 sec 14900K c 3.2/5.9 GHz 8p of 32 cores 13/128g - 13 batch

##### Go

##### CPP
- https://github.com/ObrienlabsDev/performance/tree/main/cpu/ia64/singlethread/128bit/collatz_cpp_single
- 828 sec 14900K c 3.2/5.9 GHz
- 846 sec 13900KS d 3.2/5.9 GHz
- 873 sec 13900K a 3.0/5.7 GHz
- 960 sec P1Gen6 13800H 2.5/4.1 GHz

#### 64 bit native
##### Java | 2 step odd/even 5% optimized - lambda/streams - heap/max-ram bound
- https://github.com/ObrienlabsDev/performance/tree/main/cpu/virtual/multithreaded/64bit/java-benchmark-cli
large batch 12-14 up from 5 sizes for larger memory 64-128g, cpu for Pcores goes down, thread ram overhead reduced
- 41 sec 13900K a 3.0/5.7 GHz 6g heap 23/128g - 11/12 bit batch
- 42 sec 13900K a 3.0/5.7 GHz 6g heap 23/128g - 14 bit batch
- 43 sec 13900K a 3.0/5.7 GHz 6g heap 23/128g - 15 bit batch
- 50 sec MacBook 16 M4max/12c 12g heap 1/48g - 12 bit batch
- 51 sec MacBook 16 M4max/12c 12g heap 1/48g - 14 bit batch
- 52 sec 13900K a 3.0/5.7 GHz 6g heap 128g - 10 bit batch
- 54 sec MacBook 16 M4max/12c 12g heap 1/48g - 12 bit batch
- 54 sec MacBook 16 M4max/12c 12g heap 1/48g - 15 bit batch
- 60 sec 13900K a 3.0/5.7 GHz 17g heap 128g - 5 bit batch
- 61 sec MacBook 16 M4max/12c 12g heap 1/48g - 11 bit batch
- 63 sec MacBook 16 M4max/12c 12g heap 1/48g - 5 bit batch
- 64 sec MacMini M4pro 8p4e 24g - 13 batch
- 65 sec MacMini M4pro 8p4e 24g - 14 batch
- 43 sec 14900K c 3.2/5.9 GHz 24 of 32 cores 13/128g - 12 batch
- 61 sec 14900K c 3.2/5.9 GHz 24 of 32 cores 128g - 10 batch
- 69 sec MacMini M4pro 8p4e 24g - 16 batch
- 80 sec MacMini M4pro 8p4e 24g - 12 batch
- 85 sec MacMini M4pro 8p4e 24g - 8 batch
- 85 sec P1Gen6 13800H 6p8e/20t 2.5/4.1 GHz 64g - 13 batch
- 90 sec P1Gen6 13800H 6p8e/20t 2.5/4.1 GHz 64g - 14 batch
- 105 sec MacBook 16 M1max/8c 32g - 13 batch
- 108 sec MacBook 16 M1max/8c 32g - 12 batch
- 110 sec P1Gen6 13800H 6p8e/20t 2.5/4.1 GHz 64g - 10 batch
- 111 sec P1Gen6 13800H 6p8e/20t 2.5/4.1 GHz 64g - 5 batch
- 128 sec MacBook 16 M1max/8c 32g - 5 batch
- 127 sec MacMini M2pro 6p2e 16g - 12 batch
- 129 sec MacMini M2pro 6p2e 16g - 5 batch
-     sec 13900KS d 3.2/5.9 GHz
### Single Threaded : 32 bit run
#### 64 bit native
##### CPP | 2 step odd/even 21% optimized
- https://github.com/ObrienlabsDev/performance/tree/main/cpu/ia64/singlethread/64bit/collatz_cpp_single
- 429 sec 14900K c 3.2/5.9 GHz
-     sec 13900KS d 3.2/5.9 GHz
- 447 sec 13900K a 3.0/5.7 GHz
- 489 sec P1Gen6 13800H 2.5/4.1 GHz
##### CPP
-  sec Macbook 16 M4max/12c
- 514 sec 14900K c 3.2/5.9 GHz
-     sec 13900KS d 3.2/5.9 GHz
- 535 sec 13900K a 3.0/5.7 GHz
- 592 sec P1Gen6 13800H 2.5/4.1 GHz
##### Go | 2 step odd/even 6% optimized
- https://github.com/ObrienlabsDev/performance/tree/main/cpu/virtual/singlethread/go-benchmark-cli
- 399 sec MacMini M4pro 8p4e
- 445 sec MacBook 16 M4max/12c
-     sec 14900K c 3.2/5.9 GHz
-     sec 13900KS d 3.2/5.9 GHz
-  sec 13900K a 3.0/5.7 GHz
- 475 sec MacMini M2pro 6p2e
-  sec P1Gen6 13800H 2.5/4.1 GHz
- 527 sec MacBook 16 M1max/8c
##### Go 
- 508 sec MacBook 16 M4max/12c
-     sec 14900K c 3.2/5.9 GHz
-     sec 13900KS d 3.2/5.9 GHz
- 549 sec 13900K a 3.0/5.7 GHz
- 587 sec MacMini M2pro 6p2e
- 626 sec P1Gen6 13800H 2.5/4.1 GHz
- 639 sec MacBook 16 M1max/8c
##### Java | 2 step odd/even 5% optimized
- https://github.com/ObrienlabsDev/performance/tree/main/cpu/virtual/singlethread/java-benchmark-cli
- 476 sec MacMini M4pro 8p/4e
- 507 sec MacBook 16 M4max/12c
- 546 sec MacMini M2pro 6p/2e
-     sec 14900K c 3.2/5.9 GHz
-     sec 13900KS d 3.2/5.9 GHz
-  sec 13900K a 3.0/5.7 GHz
- 589 sec MacBook 16 M1max/8c
##### Java
- 544 sec MacBook 16 M4max/12c
-  sec MacMini M2pro 6p/2e
- 648 sec MacBook 16 M1max/8c
-     sec 14900K c 3.2/5.9 GHz
-     sec 13900KS d 3.2/5.9 GHz
- 689 sec 13900K a 3.0/5.7 GHz

# Records stats
## 128 bit Multi Threaded Java (Lambda/Streams) on native long - batch 13 bit - M4Pro 24g 8p4e
20250104:0000+
```
mini08 performance-nbi % java -cp target/performance-nbi-0.0.1-SNAPSHOT.jar dev.obrienlabs.performance.nbi.Collatz128bit
Collatz multithreaded 2025 michael at obrienlabs.dev
Searching: 40 space, batch 0 of 8192 with 27 bits of 134217728 threads
m0: 0:44040219 p: 297 m: 0:43983120040 ms: 735 dur: 0
m0: 0:121634817 p: 159 m: 0:364904452 ms: 734 dur: 0
mp: 0:29360555 p: 374 m: 0:293887924 ms: 738 dur: 0
m0: 0:10485761 p: 264 m: 0:1679340436 ms: 734 dur: 0
mp: 0:111149057 p: 270 m: 0:333447172 ms: 734 dur: 0
mp: 0:54525979 p: 354 m: 0:6374281120 ms: 735 dur: 0
m0: 0:88080385 p: 205 m: 0:264241156 ms: 733 dur: 0
mp: 0:60817409 p: 158 m: 0:182452228 ms: 733 dur: 0
mp: 0:20971521 p: 128 m: 0:62914564 ms: 733 dur: 0
mp: 0:111149111 p: 381 m: 0:16669551976 ms: 1 dur: 0
m0: 0:115343391 p: 239 m: 0:10654066456 ms: 735 dur: 0
mp: 0:37748737 p: 165 m: 0:113246212 ms: 734 dur: 0
mp: 0:121634927 p: 407 m: 0:18959407720 ms: 2 dur: 0
m0: 0:115343471 p: 345 m: 0:115193922064 ms: 2 dur: 0
mp: 0:29360767 p: 480 m: 0:4179763780 ms: 1 dur: 0
m0: 0:60817519 p: 618 m: 0:527067306664 ms: 0 dur: 0
mp: 0:60817519 p: 618 m: 0:527067306664 ms: 0 dur: 0
m0: 0:104857627 p: 200 m: 0:10342881412 ms: 735 dur: 0
mp: 0:121635039 p: 619 m: 0:527067306664 ms: 17 dur: 0
m0: 0:104859183 p: 456 m: 0:566143970452 ms: 3 dur: 0
m0: 0:60819227 p: 269 m: 0:1556709308296 ms: 0 dur: 0
m0: 0:111151211 p: 381 m: 0:9238597547092 ms: 0 dur: 0
m0: 0:111162815 p: 482 m: 0:18731239518112 ms: 25 dur: 0
mp: 0:10507503 p: 675 m: 0:15208728208 ms: 16 dur: 0
m0: 0:37769471 p: 563 m: 0:60342610919632 ms: 16 dur: 0
mp: 0:37802303 p: 682 m: 0:159424614880 ms: 29 dur: 0
m0: 0:29457599 p: 604 m: 0:306296925203752 ms: 31 dur: 0
mp: 0:104956519 p: 699 m: 0:15208728208 ms: 15 dur: 0
m0: 0:111296127 p: 469 m: 0:421482397464772 ms: 53 dur: 0
m0: 0:121981103 p: 495 m: 0:474637698851092 ms: 81 dur: 1
mp: 0:88583295 p: 722 m: 0:90239155648 ms: 59 dur: 1
mp: 0:55187303 p: 742 m: 0:159424614880 ms: 65 dur: 1
mp: 0:116279419 p: 756 m: 0:159424614880 ms: 79 dur: 1
mp: 0:105707199 p: 779 m: 0:1591706254336 ms: 25 dur: 1
m0: 0:106732521 p: 575 m: 0:2185143829170100 ms: 388 dur: 1
mp: 0:86010015 p: 797 m: 0:3177300945976 ms: 893 dur: 2
m0: 0:120080895 p: 438 m: 0:3277901576118580 ms: 237 dur: 2
mp: 0:63728127 p: 949 m: 0:966616035460 ms: 845 dur: 3
mp: 0:127456255 p: 950 m: 0:966616035460 ms: 1454 dur: 5
0:10485761
0:10507503
0:20971521
0:29360555
0:29360767
0:29457599
0:37748737
0:37769471
0:37802303
0:44040219
0:54525979
0:55187303
0:60817409
0:60817519
0:60819227
0:63728127
0:86010015
0:88080385
0:88583295
0:104857627
0:104859183
0:104956519
0:105707199
0:106732521
0:111149057
0:111149111
0:111151211
0:111162815
0:111296127
0:115343391
0:115343471
0:116279419
0:120080895
0:121634817
0:121634927
0:121635039
0:121981103
0:127456255
m0: 0:246666523 p: 514 m: 0:6404797161121264 ms: 2028 dur: 7
mp: 0:254912509 p: 951 m: 0:966616035460 ms: 1456 dur: 8
mp: 0:226588897 p: 956 m: 0:966616035460 ms: 1206 dur: 9
0:226588897
0:246666523
0:254912509
m0: 0:323330559 p: 548 m: 0:10460560554145240 ms: 2344 dur: 12
m0: 0:380379879 p: 644 m: 0:11840694835853140 ms: 157 dur: 12
m0: 0:379027947 p: 600 m: 0:1414236446719942480 ms: 1073 dur: 13
mp: 0:302118529 p: 959 m: 0:966616035460 ms: 1150 dur: 14
mp: 0:268549803 p: 964 m: 0:966616035460 ms: 806 dur: 15
0:268549803
0:302118529
0:323330559
0:379027947
0:380379879
mp: 0:670617279 p: 986 m: 0:966616035460 ms: 9798 dur: 25
0:670617279
mp: 0:1341234559 p: 987 m: 0:966616035460 ms: 31844 dur: 56
0:1341234559
mp: 0:1412987847 p: 1000 m: 0:966616035460 ms: 9903 dur: 66
m0: 0:1410123943 p: 770 m: 0:7125885122794452160 ms: 137 dur: 66
0:1410123943
0:1412987847
mp: 0:1674652263 p: 1008 m: 0:966616035460 ms: 11452 dur: 78
0:1674652263
mp: 0:2610744987 p: 1050 m: 0:966616035460 ms: 45051 dur: 123
0:2610744987
mp: 0:4578853915 p: 1087 m: 0:966616035460 ms: 102500 dur: 225
0:4578853915
mp: 0:4890328815 p: 1131 m: 0:319497287463520 ms: 14475 dur: 240
0:4890328815
m0: 0:8528817511 p: 726 m: 0:-302149136352953592 ms: 176637 dur: 417
0:8528817511
mp: 0:9780657631 p: 1132 m: 0:319497287463520 ms: 63486 dur: 480
0:9780657631
mp: 0:12212032815 p: 1153 m: 0:319497287463520 ms: 119768 dur: 600
0:12212032815
mp: 0:12235060455 p: 1184 m: 0:1037298361093936 ms: 5047 dur: 605
m0: 0:12327829503 p: 543 m: 1:2275654840695500112 ms: 2996 dur: 608
0:12235060455
0:12327829503
mp: 0:13371194527 p: 1210 m: 0:319497287463520 ms: 53938 dur: 662
0:13371194527
mp: 0:17828259369 p: 1213 m: 0:319497287463520 ms: 227200 dur: 889
0:17828259369
m0: 0:23035537407 p: 836 m: 3:-4948819653289979424 ms: 261422 dur: 1150
0:23035537407
mp: 0:31694683323 p: 1219 m: 0:319497287463520 ms: 481043 dur: 1631
0:31694683323
m0: 0:45871962271 p: 555 m: 4:8554672607184627540 ms: 774222 dur: 2406
0:45871962271
m0: 0:51739336447 p: 770 m: 6:3959152699356688744 ms: 333096 dur: 2739
0:51739336447
m0: 0:59152641055 p: 871 m: 8:3925412472713788616 ms: 406554 dur: 3145
0:59152641055
m0: 0:59436135663 p: 796 m: 11:2822204561036784392 ms: 12041 dur: 3157
0:59436135663
mp: 0:63389366647 p: 1220 m: 0:319497287463520 ms: 223506 dur: 3381
0:63389366647
m0: 0:70141259775 p: 1109 m: 22:-3307999906929857464 ms: 378098 dur: 3759
0:70141259775
mp: 0:75128138247 p: 1228 m: 0:319497287463520 ms: 271675 dur: 4031
0:75128138247
m0: 0:77566362559 p: 755 m: 49:-5724174608609780944 ms: 130928 dur: 4162
0:77566362559
m0: 0:110243094271 p: 572 m: 74:7394588111761560776 ms: 1818855 dur: 5980
0:110243094271
mp: 0:133561134663 p: 1234 m: 0:319497287463520 ms: 1303518 dur: 7284
0:133561134663
mp: 0:158294678119 p: 1242 m: 0:319497287463520 ms: 1388310 dur: 8672
0:158294678119
mp: 0:166763117679 p: 1255 m: 0:319497287463520 ms: 475497 dur: 9148
0:166763117679
mp: 0:202485402111 p: 1307 m: 0:2662567439048656 ms: 2024074 dur: 11172
0:202485402111
m0: 0:204430613247 p: 790 m: 76:-5138500665980483344 ms: 113829 dur: 11286
0:204430613247
m0: 0:231913730799 p: 586 m: 118:-4818720888562128748 ms: 1550471 dur: 12836
0:231913730799
m0: 0:272025660543 p: 638 m: 1189:-3141812043948459292 ms: 2283016 dur: 15119
0:272025660543
mp: 0:404970804223 p: 1308 m: 0:2662567439048656 ms: 7635729 dur: 22755
0:404970804223
mp: 0:426635908975 p: 1321 m: 0:2662567439048656 ms: 1249090 dur: 24004
0:426635908975
m0: 0:446559217279 p: 786 m: 2143:1904360818491267984 ms: 1157501 dur: 25161
0:446559217279
m0: 0:567839862631 p: 789 m: 5450:5418023868929928788 ms: 7034895 dur: 32196
0:567839862631
mp: 0:568847878633 p: 1324 m: 0:2662567439048656 ms: 62590 dur: 32259
0:568847878633
20250104:0944
mp: 0:674190078379 p: 1332 m: 0:2662567439048656 ms: 6148200 dur: 38407
0:674190078379
20250104:1040

```
## 128 bit Single Threaded C++ on native unsigned long long - 13900KS 128g 8p16e32t
20241230+
```
m0: 0:3 0:16: p: 7 sec: 0 dur: 0
mp: 0:3 0:16: p: 7 sec: 0 dur: 0
m0: 0:7 0:52: p: 16 sec: 0 dur: 0
mp: 0:7 0:52: p: 16 sec: 0 dur: 0
mp: 0:9 0:52: p: 19 sec: 0 dur: 0
m0: 0:15 0:160: p: 17 sec: 0 dur: 0
mp: 0:19 0:88: p: 20 sec: 0 dur: 0
mp: 0:25 0:88: p: 23 sec: 0 dur: 0
m0: 0:27 0:9232: p: 111 sec: 0 dur: 0
mp: 0:27 0:9232: p: 111 sec: 0 dur: 0
mp: 0:55 0:9232: p: 112 sec: 0 dur: 0
mp: 0:73 0:9232: p: 115 sec: 0 dur: 0
mp: 0:97 0:9232: p: 118 sec: 0 dur: 0
mp: 0:129 0:9232: p: 121 sec: 0 dur: 0
mp: 0:171 0:9232: p: 124 sec: 0 dur: 0
mp: 0:231 0:9232: p: 127 sec: 0 dur: 0
m0: 0:255 0:13120: p: 47 sec: 0 dur: 0
mp: 0:313 0:9232: p: 130 sec: 0 dur: 0
mp: 0:327 0:9232: p: 143 sec: 0 dur: 0
m0: 0:447 0:39364: p: 97 sec: 0 dur: 0
m0: 0:639 0:41524: p: 131 sec: 0 dur: 0
mp: 0:649 0:9232: p: 144 sec: 0 dur: 0
m0: 0:703 0:250504: p: 170 sec: 0 dur: 0
mp: 0:703 0:250504: p: 170 sec: 0 dur: 0
mp: 0:871 0:190996: p: 178 sec: 0 dur: 0
mp: 0:1161 0:190996: p: 181 sec: 0 dur: 0
m0: 0:1819 0:1276936: p: 161 sec: 0 dur: 0
mp: 0:2223 0:250504: p: 182 sec: 0 dur: 0
mp: 0:2463 0:250504: p: 208 sec: 0 dur: 0
mp: 0:2919 0:250504: p: 216 sec: 0 dur: 0
mp: 0:3711 0:481624: p: 237 sec: 0 dur: 0
m0: 0:4255 0:6810136: p: 201 sec: 0 dur: 0
m0: 0:4591 0:8153620: p: 170 sec: 0 dur: 0
mp: 0:6171 0:975400: p: 261 sec: 0 dur: 0
m0: 0:9663 0:27114424: p: 184 sec: 0 dur: 0
mp: 0:10971 0:975400: p: 267 sec: 0 dur: 0
mp: 0:13255 0:497176: p: 275 sec: 0 dur: 0
mp: 0:17647 0:11003416: p: 278 sec: 0 dur: 0
m0: 0:20895 0:50143264: p: 255 sec: 0 dur: 0
mp: 0:23529 0:11003416: p: 281 sec: 0 dur: 0
m0: 0:26623 0:106358020: p: 307 sec: 0 dur: 0
mp: 0:26623 0:106358020: p: 307 sec: 0 dur: 0
m0: 0:31911 0:121012864: p: 160 sec: 0 dur: 0
mp: 0:34239 0:18976192: p: 310 sec: 0 dur: 0
mp: 0:35655 0:41163712: p: 323 sec: 0 dur: 0
mp: 0:52527 0:106358020: p: 339 sec: 0 dur: 0
m0: 0:60975 0:593279152: p: 334 sec: 0 dur: 0
mp: 0:77031 0:21933016: p: 350 sec: 0 dur: 0
m0: 0:77671 0:1570824736: p: 231 sec: 0 dur: 0
mp: 0:106239 0:104674192: p: 353 sec: 0 dur: 0
m0: 0:113383 0:2482111348: p: 247 sec: 0 dur: 0
m0: 0:138367 0:2798323360: p: 162 sec: 0 dur: 0
mp: 0:142587 0:593279152: p: 374 sec: 0 dur: 0
mp: 0:156159 0:41163712: p: 382 sec: 0 dur: 0
m0: 0:159487 0:17202377752: p: 183 sec: 0 dur: 0
mp: 0:216367 0:11843332: p: 385 sec: 0 dur: 0
mp: 0:230631 0:76778008: p: 442 sec: 0 dur: 0
m0: 0:270271 0:24648077896: p: 406 sec: 0 dur: 0
mp: 0:410011 0:76778008: p: 448 sec: 0 dur: 0
mp: 0:511935 0:76778008: p: 469 sec: 0 dur: 0
mp: 0:626331 0:7222283188: p: 508 sec: 0 dur: 0
m0: 0:665215 0:52483285312: p: 441 sec: 0 dur: 0
m0: 0:704511 0:56991483520: p: 242 sec: 0 dur: 0
mp: 0:837799 0:2974984576: p: 524 sec: 0 dur: 0
m0: 0:1042431 0:90239155648: p: 439 sec: 0 dur: 0
mp: 0:1117065 0:2974984576: p: 527 sec: 0 dur: 0
m0: 0:1212415 0:139646736808: p: 328 sec: 0 dur: 0
m0: 0:1441407 0:151629574372: p: 367 sec: 0 dur: 0
mp: 0:1501353 0:90239155648: p: 530 sec: 0 dur: 0
mp: 0:1723519 0:46571871940: p: 556 sec: 0 dur: 0
m0: 0:1875711 0:155904349696: p: 370 sec: 0 dur: 0
m0: 0:1988859 0:156914378224: p: 427 sec: 0 dur: 0
mp: 0:2298025 0:46571871940: p: 559 sec: 0 dur: 0
m0: 0:2643183 0:190459818484: p: 430 sec: 0 dur: 0
m0: 0:2684647 0:352617812944: p: 399 sec: 0 dur: 0
m0: 0:3041127 0:622717901620: p: 363 sec: 0 dur: 0
mp: 0:3064033 0:46571871940: p: 562 sec: 0 dur: 0
mp: 0:3542887 0:294475592320: p: 583 sec: 0 dur: 0
mp: 0:3732423 0:294475592320: p: 596 sec: 0 dur: 0
m0: 0:3873535 0:858555169576: p: 322 sec: 0 dur: 0
m0: 0:4637979 0:1318802294932: p: 573 sec: 0 dur: 0
mp: 0:5649499 0:1017886660: p: 612 sec: 1 dur: 1
m0: 0:5656191 0:2412493616608: p: 400 sec: 0 dur: 1
m0: 0:6416623 0:4799996945368: p: 483 sec: 0 dur: 1
m0: 0:6631675 0:60342610919632: p: 576 sec: 0 dur: 1
mp: 0:6649279 0:15208728208: p: 664 sec: 0 dur: 1
mp: 0:8400511 0:159424614880: p: 685 sec: 0 dur: 1
mp: 0:11200681 0:159424614880: p: 688 sec: 0 dur: 1
mp: 0:14934241 0:159424614880: p: 691 sec: 1 dur: 2
mp: 0:15733191 0:159424614880: p: 704 sec: 0 dur: 2
m0: 0:19638399 0:306296925203752: p: 606 sec: 1 dur: 3
mp: 0:31466383 0:159424614880: p: 705 sec: 2 dur: 5
mp: 0:36791535 0:159424614880: p: 744 sec: 1 dur: 6
m0: 0:38595583 0:474637698851092: p: 483 sec: 0 dur: 6
mp: 0:63728127 0:966616035460: p: 949 sec: 4 dur: 10
m0: 0:80049391 0:2185143829170100: p: 572 sec: 3 dur: 13
m0: 0:120080895 0:3277901576118580: p: 438 sec: 7 dur: 20
mp: 0:127456255 0:966616035460: p: 950 sec: 1 dur: 21
mp: 0:169941673 0:966616035460: p: 953 sec: 8 dur: 29
m0: 0:210964383 0:6404797161121264: p: 475 sec: 7 dur: 36
mp: 0:226588897 0:966616035460: p: 956 sec: 3 dur: 39
mp: 0:268549803 0:966616035460: p: 964 sec: 7 dur: 46
m0: 0:319804831 0:1414236446719942480: p: 592 sec: 10 dur: 56
mp: 0:537099607 0:966616035460: p: 965 sec: 39 dur: 95
mp: 0:670617279 0:966616035460: p: 986 sec: 25 dur: 120
mp: 0:1341234559 0:966616035460: p: 987 sec: 124 dur: 244
m0: 0:1410123943 0:7125885122794452160: p: 770 sec: 13 dur: 257
mp: 0:1412987847 0:966616035460: p: 1000 sec: 0 dur: 257
mp: 0:1674652263 0:966616035460: p: 1008 sec: 49 dur: 306
mp: 0:2610744987 0:966616035460: p: 1050 sec: 181 dur: 487
mp: 0:4578853915 0:966616035460: p: 1087 sec: 379 dur: 866
mp: 0:4890328815 0:319497287463520: p: 1131 sec: 60 dur: 926
m0: 0:8528817511 0:18144594937356598024: p: 726 sec: 713 dur: 1639
mp: 0:9780657631 0:319497287463520: p: 1132 sec: 249 dur: 1888
mp: 0:12212032815 0:319497287463520: p: 1153 sec: 485 dur: 2373
mp: 0:12235060455 0:1037298361093936: p: 1184 sec: 5 dur: 2378
m1: 0:12327829503 1:2275654840695500112: p: 543 sec: 19 dur: 2397
mp: 0:13371194527 0:319497287463520: p: 1210 sec: 209 dur: 2606
mp: 0:17828259369 0:319497287463520: p: 1213 sec: 902 dur: 3508
m1: 0:23035537407 3:13497924420419572192: p: 836 sec: 1064 dur: 4572
mp: 0:31694683323 0:319497287463520: p: 1219 sec: 1787 dur: 6359
m1: 0:45871962271 4:8554672607184627540: p: 555 sec: 2963 dur: 9322
m1: 0:51739336447 6:3959152699356688744: p: 770 sec: 1236 dur: 10558
m1: 0:59152641055 8:3925412472713788616: p: 871 sec: 1567 dur: 12125
m1: 0:59436135663 11:2822204561036784392: p: 796 sec: 60 dur: 12185
mp: 0:63389366647 0:319497287463520: p: 1220 sec: 839 dur: 13024
m1: 0:70141259775 22:15138744166779694152: p: 1109 sec: 1435 dur: 14459
mp: 0:75128138247 0:319497287463520: p: 1228 sec: 1065 dur: 15524
m1: 0:77566362559 49:12722569465099770672: p: 755 sec: 521 dur: 16045
m1: 0:110243094271 74:7394588111761560776: p: 572 sec: 7032 dur: 23077
mp: 0:133561134663 0:319497287463520: p: 1234 sec: 5057 dur: 28134
mp: 0:158294678119 0:319497287463520: p: 1242 sec: 5398 dur: 33532
mp: 0:166763117679 0:319497287463520: p: 1255 sec: 1856 dur: 35388
mp: 0:202485402111 0:2662567439048656: p: 1307 sec: 7860 dur: 43248
m1: 0:204430613247 76:13308243407729068272: p: 790 sec: 430 dur: 43678
m1: 0:231913730799 118:13628023185147422868: p: 586 sec: 6080 dur: 49758
m1: 0:272025660543 1189:15304932029761092324: p: 638 sec: 8916 dur: 58674
mp: 0:404970804223 0:2662567439048656: p: 1308 sec: 29782 dur: 88456
mp: 0:426635908975 0:2662567439048656: p: 1321 sec: 4889 dur: 93345
m1: 0:446559217279 2143:1904360818491267984: p: 786 sec: 4506 dur: 97851
m1: 0:567839862631 5450:5418023868929928788: p: 789 sec: 27625 dur: 125476
mp: 0:568847878633 0:2662567439048656: p: 1324 sec: 230 dur: 125706
mp: 0:674190078379 0:2662567439048656: p: 1332 sec: 24189 dur: 149895
m1: 0:871673828443 21714:6140004720918243904: p: 650 sec: 45433 dur: 195328
mp: 0:881715740415 0:5234135688127384: p: 1335 sec: 2318 dur: 197646
mp: 0:989345275647 0:1219624271099764: p: 1348 sec: 24896 dur: 222542
mp: 0:1122382791663 0:2662567439048656: p: 1356 sec: 30977 dur: 253519
mp: 0:1444338092271 0:1219624271099764: p: 1408 sec: 75267 dur: 328786
mp: 0:1899148184679 0:1037298361093936: p: 1411 sec: 107540 dur: 436326


```

# Links
