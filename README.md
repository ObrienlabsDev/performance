# Abstract
This article attempts to systematically determine the optimized spot where we can push our hardware to the fullest possible use.
Multithreaded optimization depends on multiple factors including CPU/GPU type (M4Max vs 14900 or MetalCUDA.  Operations involving space-time tradeoffs like heap usage need to be fine tuned around batch sizes.

A secondary requirement of this multi-language work is to demonstrate, test and learn about concurrency and throughput of various languages under various types of bound workloads - https://github.com/ObrienlabsDev/blog/blob/main/programming_language_index.md
# Architecture
see https://github.com/ObrienlabsDev/blog/wiki/Performance
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

### Optimization 5: Turn off real time AV protection
Either map out the drive or turn off Anti Virus protection.  Windows systems are particularly slower because defender will kick in during compilation and runtime with up to a full core that is bound by disk access.
```
33% speed increase on same p1gen6 system 
mp: 0:2610744987 p: 1050 m: 0:966616035460 ms: 101041 dur: 270
to
mp: 0:2610744987 p: 1050 m: 0:966616035460 ms: 67696 dur: 182
```
![image](https://github.com/user-attachments/assets/b0bf1241-48bb-4119-adf4-81a445849c03)

# Performance Numbers

- 17.6h on an M4Pro 8p4e to check up to 40 bits (79 bit max) #60 on http://www.ericr.nl/wondrous/pathrecs.html
```
60	871673,828443	400558,740821,250122,033728	0.527	40	79	Leavens & Vermeulen
```

## Criteria
- CON: Single / Multi threaded (both CPU and GPU (you can use just 1 ALU core in a GPU)
- PRU: CPU / GPU
- FRM: native / framework (as in java long (64 bit max) or java BigInteger (open ended))
- BIT: 64 / 128 / 256 bit
- LAN: language (C, Swift, Go, Java, Python, Rust)
- ARC: Architecture (IA64/AMD64 or ARM64 - or agnostic (JIT compiled Go))
- 

## GPU
### Multi Threaded : 32 bit run (search 0-(2^32-1) odd integer space)
#### 128 bit native
##### CUDA 12.6: CPP
- 14 sec 14900KS d RTX-A6000 single 55% GPU 45% TDP .5g/48g - 32k threads / 512 threads/block
- 14 sec RTX-4090 single 16384 cores 48% GPU 24% TDP- 20 batch 40960 threads 512 threads/block 80 blocks
- 17 sec P1Gen6 13800H RTX-3500 Ada mobile 5120 cores 60% GPU - 20 batch, 40960 threads
- 18 sec RTX-A4500 single
- 18 sec RTX-A4000 single
- 20 sec RTX-5000 TU104 16g mobile P17gen1
#### 64 bit native
Sec: 4 GlobalMax: 319804831 : 1414236446719942480 last search : 1073741825
-  9 sec 14900KS d RTX-A6000 single 45% GPU 24% TDP .9g/48g - 32k threads / 256 threads/block
- 10 sec 13900K b 4090 single 45% GPU 22% TDP .9g/24g 32k threads / 256 threads/block 
- 12 sec 13900K a RTX-A4000 single 45% GPU 58% TDP .9g/16g

## CPU
### Multi Threaded : 40 bit run
#### 128 bit native
##### Java 
- sec Macbook 16 M4max 12p4e - 13 batch
- 63554 sec MacMini M4pro 8p4e 24g - 13 batch
- sec MacBook 16 M1max 8p2e 32g - 13 batch
- sec P1Gen6 13800H 6p8e/20t 2.5/4.1 GHz 64g - 13 batch
- sec 14900K c 3.2/5.9 GHz 8p of 32 cores 13/128g - 13 batch
- sec 13900k a 3.0/5.7 GHz 8p/16e/32t 128g - 13 batch
### Multi Threaded : 37 bit run
#### 128 bit native
##### Java 
- 5833 sec Macbook 16 M4max 12p4e - 13 batch
- 6701 sec MacMini M4pro 8p4e 24g - 13 batch
- 10274 sec MacMini M4 4p6e/10v 16g - 13 batch
- sec MacBook 16 M1max 8p2e 32g - 13 batch
- sec P1Gen6 13800H 6p8e/20t 2.5/4.1 GHz 64g - 13 batch
- 15292 sec 13900k a 3.0/5.7 GHz 8p/16e/32t 128g - 13 batch
- 16988 sec 14900K c 3.2/5.9 GHz 8p of 32 cores 13/128g - 13 batch
- 
### Multi Threaded : 32 bit run (search 0-(2^32-1) odd integer space)
#### 128 bit native
##### Java
- 114 sec Macbook 16 M4max 12p4e - 13 batch
- 151 sec MacMini M4pro 8p4e16v 24g - 14 batch
- 153 sec MacMini M4pro 8p4e16v 24g - 11/13 batch
- 225 sec MacBook 16 M1max 8p2e 32g - 13 batch
- 232 sec MacMini M2pro 6p4e 16g - 15 batch
- 235 sec MacMini M2pro 6p4e 16g - 16 batch
- 243 sec MacMini M2pro 6p4e 16g - 14 batch
- 259 sec MacMini M4 4p6e/10v 16g - 14 batch
- 299 sec MacMini M2pro 6p4e 16g - 13 batch
- 308 sec P1Gen6 13800H 6p8e/20t 2.5/4.1 GHz 64g - 13 batch noAV
- 315 sec P1Gen6 13800H 6p8e/20t 2.5/4.1 GHz 64g - 13 batch
- 318 sec MacMini M4 4p6e/10v 16g - 11 batch
- 324 sec MacMini M4 4p6e/10v 16g - 12 batch
- 327 sec MacMini M4 4p6e/10v 16g - 10/13 batch
- 339 sec 13900k a 3.0/5.7 GHz 8p/16e/32t 128g - 13/ batch noAV
- 360 sec 13900k a 3.0/5.7 GHz 8p/16e/32t 128g - 15 batch noAV
- 360 sec MacMini M2pro 6p4e 16g - 11 batch
- 392 sec 14900K c 3.2/5.9 GHz 8p of 32 cores 13/128g - 13 batch noAV
- 455 sec Hyperv Ubuntu 24 on 13900k a 3.0/5.7 GHz 16 of 8p/16e/32t 128g


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
- 115 sec MacMini M4 4p6e/10v 16g - 12 batch
- 127 sec MacMini M2pro 6p2e 16g - 12 batch
- 128 sec MacBook 16 M1max/8c 32g - 5 batch
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
## 128 bit CUDA (5120 to 32768 cores) - RTX-A6000 or dual RTX-4090
55% GPU at 24% TDP

```
20250110:0130
GPU00:Sec: 0 GlobalMax: 0:3: 0:16 last search: 81923
GPU00:Sec: 0 GlobalMax: 0:7: 0:52 last search: 81923
GPU00:Sec: 0 GlobalMax: 0:15: 0:160 last search: 81923
GPU00:Sec: 0 GlobalMax: 0:27: 0:9232 last search: 81923
GPU00:Sec: 0 GlobalMax: 0:255: 0:13120 last search: 81923
GPU00:Sec: 0 GlobalMax: 0:447: 0:39364 last search: 81923
GPU00:Sec: 0 GlobalMax: 0:639: 0:41524 last search: 81923
GPU00:Sec: 0 GlobalMax: 0:703: 0:250504 last search: 81923
GPU00:Sec: 0 GlobalMax: 0:1819: 0:1276936 last search: 81923
GPU00:Sec: 0 GlobalMax: 0:4255: 0:6810136 last search: 81923
GPU00:Sec: 0 GlobalMax: 0:4591: 0:8153620 last search: 81923
GPU00:Sec: 0 GlobalMax: 0:9663: 0:27114424 last search: 81923
GPU00:Sec: 0 GlobalMax: 0:20895: 0:50143264 last search: 81923
GPU00:Sec: 0 GlobalMax: 0:26623: 0:106358020 last search: 81923
GPU00:Sec: 0 GlobalMax: 0:31911: 0:121012864 last search: 81923
GPU00:Sec: 0 GlobalMax: 0:60975: 0:593279152 last search: 81923
GPU00:Sec: 0 GlobalMax: 0:77671: 0:1570824736 last search: 81923
GPU00:Sec: 0 GlobalMax: 0:113383: 0:2482111348 last search: 163843
GPU00:Sec: 0 GlobalMax: 0:138367: 0:2798323360 last search: 163843
GPU00:Sec: 0 GlobalMax: 0:159487: 0:17202377752 last search: 163843
GPU00:Sec: 0 GlobalMax: 0:270271: 0:24648077896 last search: 327683
GPU00:Sec: 0 GlobalMax: 0:665215: 0:52483285312 last search: 737283
GPU00:Sec: 0 GlobalMax: 0:704511: 0:56991483520 last search: 737283
GPU00:Sec: 0 GlobalMax: 0:1042431: 0:90239155648 last search: 1064963
GPU00:Sec: 0 GlobalMax: 0:1212415: 0:139646736808 last search: 1228803
GPU00:Sec: 0 GlobalMax: 0:1441407: 0:151629574372 last search: 1474563
GPU00:Sec: 0 GlobalMax: 0:1875711: 0:155904349696 last search: 1884163
GPU00:Sec: 0 GlobalMax: 0:1988859: 0:156914378224 last search: 2048003
GPU00:Sec: 0 GlobalMax: 0:2643183: 0:190459818484 last search: 2703363
GPU00:Sec: 0 GlobalMax: 0:2684647: 0:352617812944 last search: 2703363
GPU00:Sec: 0 GlobalMax: 0:3041127: 0:622717901620 last search: 3112963
GPU00:Sec: 0 GlobalMax: 0:3873535: 0:858555169576 last search: 3932163
GPU00:Sec: 0 GlobalMax: 0:4637979: 0:1318802294932 last search: 4669443
GPU00:Sec: 0 GlobalMax: 0:5656191: 0:2412493616608 last search: 5734403
GPU00:Sec: 0 GlobalMax: 0:6416623: 0:4799996945368 last search: 6471683
GPU00:Sec: 0 GlobalMax: 0:6631675: 0:60342610919632 last search: 6635523
GPU00:Sec: 0 GlobalMax: 0:19638399: 0:306296925203752 last search: 19660803
GPU00:Sec: 0 GlobalMax: 0:38595583: 0:474637698851092 last search: 38666243
GPU00:Sec: 0 GlobalMax: 0:80049391: 0:2185143829170100 last search: 80117763
GPU00:Sec: 0 GlobalMax: 0:120080895: 0:3277901576118580 last search: 120094723
GPU00:Sec: 1 GlobalMax: 0:210964383: 0:6404797161121264 last search: 211025923
GPU00:Sec: 1 GlobalMax: 0:319804831: 0:1414236446719942480 last search: 319815683
GPU00:Sec: 4 GlobalMax: 0:1410123943: 0:7125885122794452160 last search: 1410170883
GPU00:Sec: 28 GlobalMax: 0:8528817511: 0:18144594937356598024 last search: 8528855043
GPU01:Sec: 40 GlobalMax: 0:12327829503: 1:2275654840695500112 last search: 12327895043
GPU01:Sec: 74 GlobalMax: 0:23035537407: 3:13497924420419572192 last search: 23035576323
GPU01:Sec: 147 GlobalMax: 0:45871962271: 4:8554672607184627540 last search: 45872005123
GPU01:Sec: 166 GlobalMax: 0:51739336447: 6:3959152699356688744 last search: 51739361283
GPU01:Sec: 189 GlobalMax: 0:59152641055: 8:3925412472713788616 last search: 59152711683
GPU01:Sec: 190 GlobalMax: 0:59436135663: 11:2822204561036784392 last search: 59436154883
GPU01:Sec: 225 GlobalMax: 0:70141259775: 22:15138744166779694152 last search: 70141296643
GPU01:Sec: 248 GlobalMax: 0:77566362559: 49:12722569465099770672 last search: 77566443523
GPU01:Sec: 354 GlobalMax: 0:110243094271: 74:7394588111761560776 last search: 110243102723
GPU01:Sec: 658 GlobalMax: 0:204430613247: 76:13308243407729068272 last search: 204430622723
GPU01:Sec: 747 GlobalMax: 0:231913730799: 118:13628023185147422868 last search: 231913799683
GPU01:Sec: 877 GlobalMax: 0:272025660543: 1189:15304932029761092324 last search: 272025681923
GPU01:Sec: 1443 GlobalMax: 0:446559217279: 2143:1904360818491267984 last search: 446559272963
GPU01:Sec: 1838 GlobalMax: 0:567839862631: 5450:5418023868929928788 last search: 567839866883
GPU01:Sec: 2830 GlobalMax: 0:871673828443: 21714:6140004720918243904 last search: 871673856003
GPU01:Sec: 8745 GlobalMax: 0:2674309547647: 41764:10130355336659361648 last search: 2674309611523
overnight 20250111:0900
GPU01:Sec: 12173 GlobalMax: 0:3716509988199: 11272258:4885724866165006536 last search: 3716510023683
GPU01:Sec: 29652 GlobalMax: 0:9016346070511: 13673390:1233423889223725952 last search: 9016346132483
```
20250111: within 9h of at 55% GPU or 24% TDP of an RTX-A6000 GPU we are at record 63 of http://www.ericr.nl/wondrous/pathrecs.html and switching from those created by "Leavens & Vermuelen" up to bit 44 to "Tomás Oliveira e Silva" at bit 46.

```
63	9,016346,070511	252,229527,183443,335194,424192	3.103	44	88	Leavens & Vermeulen
Time duration: 29652 seconds or 8.3h
```

## 128 bit Multi Threaded Java (Lambda/Streams) on native long - batch 13 bit - M4Pro 24g 8p4e
20250104:0000+
```
Searching: 37 space, batch 0 of 8192 with 24 bits of 16777216 threads over a 13 batch size
m0: 0:5505031 p: 201 m: 0:37158964 ms: 105 dur: 0
mp: 0:7602177 p: 248 m: 0:22806532 ms: 105 dur: 0
m0: 0:9699359 p: 163 m: 0:7265088592 ms: 107 dur: 0
mp: 0:6815765 p: 315 m: 0:20447296 ms: 106 dur: 0
m0: 0:7864321 p: 261 m: 0:1679340436 ms: 105 dur: 0
mp: 0:1310733 p: 261 m: 0:3932200 ms: 106 dur: 0
mp: 0:2621441 p: 174 m: 0:7864324 ms: 105 dur: 0
m0: 0:11010049 p: 171 m: 0:33030148 ms: 105 dur: 0
mp: 0:8126491 p: 336 m: 0:1692449296 ms: 106 dur: 0
m0: 0:15204353 p: 267 m: 0:71258776 ms: 105 dur: 0
m0: 0:6553607 p: 90 m: 0:44236852 ms: 105 dur: 0
mp: 0:4718715 p: 374 m: 0:183878584 ms: 107 dur: 0
m0: 0:13893703 p: 267 m: 0:3468923008 ms: 107 dur: 0
m0: 0:7340035 p: 204 m: 0:33030160 ms: 105 dur: 0
m0: 0:6291487 p: 227 m: 0:1961326384 ms: 106 dur: 0
m0: 0:3670047 p: 195 m: 0:1930687792 ms: 106 dur: 0
mp: 0:9699431 p: 481 m: 0:6384303520 ms: 2 dur: 0
m0: 0:6815839 p: 266 m: 0:21807010024 ms: 4 dur: 0
m0: 0:7340143 p: 248 m: 0:26420057872 ms: 4 dur: 0
m0: 0:15204519 p: 523 m: 0:62407898116 ms: 9 dur: 0
mp: 0:15204519 p: 523 m: 0:62407898116 ms: 0 dur: 0
m0: 0:8127447 p: 566 m: 0:125218704148 ms: 15 dur: 0
mp: 0:8127447 p: 566 m: 0:125218704148 ms: 0 dur: 0
m0: 0:8128207 p: 566 m: 0:351079315396 ms: 0 dur: 0
mp: 0:4723849 p: 586 m: 0:294475592320 ms: 3 dur: 0
mp: 0:6298465 p: 589 m: 0:294475592320 ms: 1 dur: 0
m0: 0:15221063 p: 554 m: 0:487459424464 ms: 29 dur: 0
m0: 0:11030497 p: 308 m: 0:858555169576 ms: 10 dur: 0
m0: 0:13913939 p: 572 m: 0:1318802294932 ms: 7 dur: 0
mp: 0:13920103 p: 603 m: 0:150311737960 ms: 23 dur: 0
mp: 0:6355687 p: 607 m: 0:1017886660 ms: 117 dur: 0
m0: 0:6631675 p: 576 m: 0:60342610919632 ms: 50 dur: 0
mp: 0:6649279 p: 664 m: 0:15208728208 ms: 60 dur: 0
mp: 0:11200681 p: 688 m: 0:159424614880 ms: 183 dur: 0
mp: 0:14934241 p: 691 m: 0:159424614880 ms: 157 dur: 0
mp: 0:15733191 p: 704 m: 0:159424614880 ms: 4 dur: 0
m0: 0:19638399 p: 606 m: 0:306296925203752 ms: 345 dur: 1
mp: 0:31466383 p: 705 m: 0:159424614880 ms: 289 dur: 1
m0: 0:38595583 p: 483 m: 0:474637698851092 ms: 311 dur: 1
mp: 0:36791535 p: 744 m: 0:159424614880 ms: 4 dur: 1
mp: 0:63728127 p: 949 m: 0:966616035460 ms: 1296 dur: 3
m0: 0:80049391 p: 572 m: 0:2185143829170100 ms: 747 dur: 3
m0: 0:120080895 p: 438 m: 0:3277901576118580 ms: 1670 dur: 5
mp: 0:127456255 p: 950 m: 0:966616035460 ms: 238 dur: 5
mp: 0:169941673 p: 953 m: 0:966616035460 ms: 1929 dur: 7
m0: 0:210964383 p: 475 m: 0:6404797161121264 ms: 1046 dur: 8
mp: 0:226588897 p: 956 m: 0:966616035460 ms: 427 dur: 9
mp: 0:268549803 p: 964 m: 0:966616035460 ms: 1886 dur: 10
m0: 0:319804831 p: 592 m: 0:1414236446719942480 ms: 2015 dur: 13
mp: 0:537099607 p: 965 m: 0:966616035460 ms: 8118 dur: 21
mp: 0:670617279 p: 986 m: 0:966616035460 ms: 3946 dur: 25
mp: 0:1341234559 p: 987 m: 0:966616035460 ms: 25037 dur: 50
mp: 0:1412987847 p: 1000 m: 0:966616035460 ms: 3085 dur: 53
m0: 0:1410123943 p: 770 m: 0:7125885122794452160 ms: 498 dur: 53
mp: 0:1674652263 p: 1008 m: 0:966616035460 ms: 9409 dur: 63
mp: 0:2610744987 p: 1050 m: 0:966616035460 ms: 35488 dur: 98
mp: 0:4578853915 p: 1087 m: 0:966616035460 ms: 73254 dur: 171
mp: 0:4890328815 p: 1131 m: 0:319497287463520 ms: 12417 dur: 184
m0: 0:8528817511 p: 726 m: 0:-302149136352953592 ms: 138529 dur: 322
mp: 0:9780657631 p: 1132 m: 0:319497287463520 ms: 47390 dur: 370
mp: 0:12212032815 p: 1153 m: 0:319497287463520 ms: 94483 dur: 464
mp: 0:12235060455 p: 1184 m: 0:1037298361093936 ms: 1325 dur: 465
m0: 0:12327829503 p: 543 m: 1:2275654840695500112 ms: 3467 dur: 469
mp: 0:13371194527 p: 1210 m: 0:319497287463520 ms: 40416 dur: 509
mp: 0:17828259369 p: 1213 m: 0:319497287463520 ms: 174953 dur: 684
m0: 0:23035537407 p: 836 m: 3:-4948819653289979424 ms: 207693 dur: 892
mp: 0:31694683323 p: 1219 m: 0:319497287463520 ms: 358851 dur: 1251
m0: 0:45871962271 p: 555 m: 4:8554672607184627540 ms: 605298 dur: 1856
m0: 0:51739336447 p: 770 m: 6:3959152699356688744 ms: 249188 dur: 2105
m0: 0:59152641055 p: 871 m: 8:3925412472713788616 ms: 317847 dur: 2423
m0: 0:59436135663 p: 796 m: 11:2822204561036784392 ms: 12562 dur: 2436
mp: 0:63389366647 p: 1220 m: 0:319497287463520 ms: 170167 dur: 2606
m0: 0:70141259775 p: 1109 m: 22:-3307999906929857464 ms: 290905 dur: 2897
mp: 0:75128138247 p: 1228 m: 0:319497287463520 ms: 214272 dur: 3111
m0: 0:77566362559 p: 755 m: 49:-5724174608609780944 ms: 106654 dur: 3218
m0: 0:110243094271 p: 572 m: 74:7394588111761560776 ms: 1433593 dur: 4651
mp: 0:133561134663 p: 1234 m: 0:319497287463520 ms: 1010199 dur: 5662
last number: 137438953472
completed: 5833894

mini08 performance-nbi % java -cp target/performance-nbi-0.0.1-SNAPSHOT.jar dev.obrienlabs.performance.nbi.Collatz128bit
Collatz multithreaded 2025 michael at obrienlabs.dev
Searching: 40 space, batch 0 of 8192 with 27 bits of 134217728 threads
...
mp: 0:133561134663 p: 1234 m: 0:319497287463520 ms: 1303518 dur: 7284
mp: 0:158294678119 p: 1242 m: 0:319497287463520 ms: 1388310 dur: 8672
mp: 0:166763117679 p: 1255 m: 0:319497287463520 ms: 475497 dur: 9148
mp: 0:202485402111 p: 1307 m: 0:2662567439048656 ms: 2024074 dur: 11172
m0: 0:204430613247 p: 790 m: 76:-5138500665980483344 ms: 113829 dur: 11286
m0: 0:231913730799 p: 586 m: 118:-4818720888562128748 ms: 1550471 dur: 12836
m0: 0:272025660543 p: 638 m: 1189:-3141812043948459292 ms: 2283016 dur: 15119
mp: 0:404970804223 p: 1308 m: 0:2662567439048656 ms: 7635729 dur: 22755
mp: 0:426635908975 p: 1321 m: 0:2662567439048656 ms: 1249090 dur: 24004
m0: 0:446559217279 p: 786 m: 2143:1904360818491267984 ms: 1157501 dur: 25161
m0: 0:567839862631 p: 789 m: 5450:5418023868929928788 ms: 7034895 dur: 32196
mp: 0:568847878633 p: 1324 m: 0:2662567439048656 ms: 62590 dur: 32259
20250104:0944
mp: 0:674190078379 p: 1332 m: 0:2662567439048656 ms: 6148200 dur: 38407
20250104:1040
40/79 bit
m0: 0:871673828443 p: 650 m: 21714:6140004720918243904 ms: 11642008 dur: 50049
mp: 0:881715740415 p: 1335 m: 0:5234135688127384 ms: 597153 dur: 50646
mp: 0:989345275647 p: 1348 m: 0:1219624271099764 ms: 6370486 dur: 57017
20250104:1725
20250105:1745
last number: 1099511627776
completed: 63554039

continue with M1Max 929%

mp: 0:1122382791663 p: 1356 m: 0:2662567439048656 ms: 11430189 dur: 93468
mp: 0:1444338092271 p: 1408 m: 0:1219624271099764 ms: 27968005 dur: 121436
mp: 0:1899148184679 p: 1411 m: 0:1037298361093936 ms: 39688329 dur: 161124
mp: 0:2081751768559 p: 1437 m: 4:6202015729192499496 ms: 16038774 dur: 177163
42/80 bit
m0: 0:2674309547647 p: 1029 m: 41764:-8316388737050189968 ms: 51696273 dur: 228859
20250106
mp: 0:2775669024745 p: 1440 m: 4:6202015729192499496 ms: 9130971 dur: 237990

continue with M2Pro 970% - down tto 500 during heap work 
PID    COMMAND      %CPU      TIME     #TH    #WQ   #PORT MEM    PURG   CMPRS  PGRP  PPID  STATE    BOOSTS                 %CPU_ME %CPU_OTHRS UID  FAULTS      COW   
41970  java         525.4     932 hrs  39/1   1     145   4259M- 0B     35M-   41970 1248  running  *0[1]                  0.00000 0.00000    501  2147483647  3252


m0: 0:2674309547647 p: 1029 m: 41764:-8316388737050189968 ms: 54514175 dur: 239425
20250107:1800
mp: 0:3700892032993 p: 1443 m: 4:6202015729192499496 ms: 85975157 dur: 334849
m0: 0:3716509988199 p: 802 m: 11272258:4885724866165006536 ms: 1447490 dur: 336297
mp: 0:3743559068799 p: 1549 m: 4:6202015729192499496 ms: 2489022 dur: 338786
42/88 bit
20250109
1500h
last number: 4398046511104
completed: 399318132
for 42/16
50 bit...
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
mp: 0:2081751768559 4:6202015729192499496: p: 1437 sec: 43451 dur: 479777

```

# Links
