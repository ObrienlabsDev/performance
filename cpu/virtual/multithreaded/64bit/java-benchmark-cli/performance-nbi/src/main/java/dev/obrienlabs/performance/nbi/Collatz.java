package dev.obrienlabs.performance.nbi;

import java.util.List;
import java.util.concurrent.atomic.AtomicLong;
import java.util.stream.Collectors;
import java.util.stream.LongStream;

/**
 * 20250101
 * Michael O'Brien michael at obrienlabs.dev
 * 
 * Architecture
 * map the search space by interleaved UOW (1,3,5,7) - to 4 threads
 * reduce the result by comparing thread local maximums
 * 
 */
public class Collatz {
	
	private long secondsLast = System.currentTimeMillis();
	
	private AtomicLong globalMaxValue = new AtomicLong(1L);
	private AtomicLong globalMaxPath = new AtomicLong(1L);
	
	public boolean isCollatzMax(long oddSearchCurrent, long secondsStart) {
		boolean result = false;
		//Long result = 0L;
		long current = oddSearchCurrent;
		long path = 0L;
		long maxValue = 1L;
		
		for (;;) {	
			if (current % 2 == 0) {
				current = current >> 1;
			} else {
				/**
				  if even divide by 2, if odd multiply by 3 and add 1
				  or for odd numbers do 2 steps to optimize (n + n/2 + 1) - because we truncate divides
				  6% speed up for Java, 20% for C, 6% for Go
				*/
				current = (current >> 1) + current  + 1L; // optimize
				//current = (current << 1) + current + 1L
				path++;
				if (current > maxValue) { // check limits
					maxValue = current;
				}
			}

			path++;

			// check completion of this number
			if (current < 2L) {
				// check limits
				if (maxValue > globalMaxValue.get()) {
					globalMaxValue.set(maxValue);
					System.out.println("m0: " + oddSearchCurrent + " p: " + path + " m: " + (maxValue << 1) + " ms: " 
						+ (System.currentTimeMillis() - secondsLast) + " dur: " + ((System.currentTimeMillis() - secondsStart) / 1000));
					secondsLast = System.currentTimeMillis();
					result = true;
					//result = Long.valueOf(current);
				}
				if (path > globalMaxPath.get()) {
					globalMaxPath.set(path);
					System.out.println("mp: " + oddSearchCurrent + " p: " + path + " m: " + (maxValue << 1) + " ms: " 
						+ (System.currentTimeMillis() - secondsLast) + " dur: " + ((System.currentTimeMillis() - secondsStart) / 1000));
					secondsLast = System.currentTimeMillis();
					result = true;
					//result = Long.valueOf(current);
				}
				break;
			}
		}
		return result;
	}
	
	public void searchCollatzParallel(long oddSearchCurrent, long secondsStart) {
		long batchBits = 12; // adjust this based on the chip architecture 
		
		long searchBits = 32;
		long batches = 1 << batchBits;
		long threadBits = searchBits - batchBits;
		long threads = 1 << threadBits;
		
		System.out.println("Searching: " + searchBits + " space, batch " + "0" + " of " 
				+ batches + " with " + threadBits +" bits of " + threads + " threads"
				+ " under vCPUs: " + Runtime.getRuntime().availableProcessors()
				+ " memory: " + Runtime.getRuntime().totalMemory());
		
		for (long part = 0; part < (batches + 1) ; part++) {	
			// generate a limited collection (CopyOnWriteArrayList not required as r/o) for the search space - 32 is a good
			List<Long> oddNumbers = LongStream
					.range(1L + (part * threads), ((1 + part) * threads) - 1)
					.filter(x -> x % 2 != 0) // TODO: find a way to avoid this filter using range above
					.boxed()
					.collect(Collectors.toList());
			
			// filter on max value or path
			List<Long> results = oddNumbers
				.parallelStream()
				.filter(num -> isCollatzMax(num.longValue(), secondsStart))
				.collect(Collectors.toList());

			results.stream().sorted().forEach(x -> System.out.println(x));
		}
		System.out.println("last number: " + ((1 + (batches) * threads) - 1));
	}

	public static void main(String[] args) {
		System.out.println("Collatz multithreaded 2025 michael at obrienlabs.dev");
		Collatz collatz = new Collatz();

		//long oddSearchStart = 1L;        // must be odd
		//long oddSearchEnd = 4294967295L; //18446744073709551615 // must be odd
		//long oddSearchIncrement = 2L;
		long oddSearchCurrent = 1L;
		long secondsStart = System.currentTimeMillis();

		collatz.searchCollatzParallel(oddSearchCurrent, secondsStart);
		/*for(oddSearchCurrent = oddSearchStart; oddSearchCurrent < oddSearchEnd; oddSearchCurrent += oddSearchIncrement) {
			collatz.searchCollatzParallel(oddSearchCurrent, secondsStart);
		}*/
		System.out.println("completed: " + (System.currentTimeMillis() - secondsStart));
	}

}
