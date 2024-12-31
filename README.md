# performance
## Criteria
- CON: Single / Multi threaded (both CPU and GPU (you can use just 1 ALU core in a GPU)
- PRU: CPU / GPU
- FRM: native / framework (as in java long (64 bit max) or java BigInteger (open ended))
- BIT: 64 / 128 / 256 bit
- LAN: language (C, Swift, Go, Java, Python, Rust)
- ARC: Architecture (IA64/AMD64 or ARM64 - or agnostic (JIT compiled Go))
- 

## CPU
### Single Threaded : 64 bit native - 32 bit run
#### Go 
- 508 sec MacBook 16 M4max/12c
- 549 sec 13900K a 3.0/5.7 GHz
- 587 sec MacMini M4pro/6c
- 626 sec P1Gen6 13800H 2.5/4.1 GHz
- 639 sec MacBook 16 M1max/8c
#### Java
- 544 sec MacBook 16 M4max/12c
- 648 sec MacMini M4pro/6c
- 689 sec 13900K a 3.0/5.7 GHz
### Single Threaded : 128 bit native - 32 bit run
### CPP
- sec 13900KS d 3.2/5.9 GHz
- 828 sec 14900K c 3.2/5.9 GHz
- 873 sec 13900K a 3.0/5.7 GHz
- 960 sec P1Gen6 13800H 2.5/4.1 GHz

## GPU
