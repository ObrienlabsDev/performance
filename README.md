# Architecture
The 3n+1, collatz or hailstone numbers problem - https://en.wikipedia.org/wiki/Collatz_conjecture
## Optimizations
  The focus here is on the base algorithm which is independent of the programming language used.  However, there are 'architecture aware' optimizations that we will detail as we get closer to the hardware using AVX, CUDA or Metal.
### Optimization 1: Combine odd/even steps
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
### Optimization 2: Roll up all divide by 2 sequences
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
##### Java | 2 step odd/even 5% optimized - lambda/streams
- 112 sec 13900K a 3.0/5.7 GHz 16g heap
- 115 sec MacBook 16 M4max/12c 12g heap
- 231 sec P1Gen6 13800H 2.5/4.1 GHz
- 239 sec MacBook 16 M1max/8c
- 285 sec MacMini M4pro/6c
-     sec 14900K c 3.2/5.9 GHz
-     sec 13900KS d 3.2/5.9 GHz
-  sec 13900K a 3.0/5.7 GHz
### Single Threaded : 32 bit run
#### 64 bit native
##### CPP | 2 step odd/even 21% optimized
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
- 445 sec MacBook 16 M4max/12c
-     sec 14900K c 3.2/5.9 GHz
-     sec 13900KS d 3.2/5.9 GHz
-  sec 13900K a 3.0/5.7 GHz
- 475 sec MacMini M4pro/6c
-  sec P1Gen6 13800H 2.5/4.1 GHz
-  sec MacBook 16 M1max/8c
##### Go 
- 508 sec MacBook 16 M4max/12c
-     sec 14900K c 3.2/5.9 GHz
-     sec 13900KS d 3.2/5.9 GHz
- 549 sec 13900K a 3.0/5.7 GHz
- 587 sec MacMini M4pro/6c
- 626 sec P1Gen6 13800H 2.5/4.1 GHz
- 639 sec MacBook 16 M1max/8c
##### Java | 2 step odd/even 5% optimized
- 517 sec MacBook 16 M4max/12c
- 546 sec MacMini M4pro/6c
-     sec 14900K c 3.2/5.9 GHz
-     sec 13900KS d 3.2/5.9 GHz
-  sec 13900K a 3.0/5.7 GHz
- 591 sec MacBook 16 M1max/8c
##### Java
- 544 sec MacBook 16 M4max/12c
-  sec MacMini M4pro/6c
- 648 sec MacBook 16 M1max/8c
-     sec 14900K c 3.2/5.9 GHz
-     sec 13900KS d 3.2/5.9 GHz
- 689 sec 13900K a 3.0/5.7 GHz

#### 128 bit native
##### Go
##### Java
##### CPP
- 828 sec 14900K c 3.2/5.9 GHz
- 846 sec 13900KS d 3.2/5.9 GHz
- 873 sec 13900K a 3.0/5.7 GHz
- 960 sec P1Gen6 13800H 2.5/4.1 GHz

## GPU


# Links
