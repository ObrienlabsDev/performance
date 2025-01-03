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

# Performance Numbers

## Criteria
- CON: Single / Multi threaded (both CPU and GPU (you can use just 1 ALU core in a GPU)
- PRU: CPU / GPU
- FRM: native / framework (as in java long (64 bit max) or java BigInteger (open ended))
- BIT: 64 / 128 / 256 bit
- LAN: language (C, Swift, Go, Java, Python, Rust)
- ARC: Architecture (IA64/AMD64 or ARM64 - or agnostic (JIT compiled Go))
- 

## CPU
### Multi Threaded : 32 bit run
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
- 399 sec MacMin M4pro 8p4e
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

#### 128 bit native
##### Go
##### Java
##### CPP
- https://github.com/ObrienlabsDev/performance/tree/main/cpu/ia64/singlethread/128bit/collatz_cpp_single
- 828 sec 14900K c 3.2/5.9 GHz
- 846 sec 13900KS d 3.2/5.9 GHz
- 873 sec 13900K a 3.0/5.7 GHz
- 960 sec P1Gen6 13800H 2.5/4.1 GHz

## GPU


# Links
