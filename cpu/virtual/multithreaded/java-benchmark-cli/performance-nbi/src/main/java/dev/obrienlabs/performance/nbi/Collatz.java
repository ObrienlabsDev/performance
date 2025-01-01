package dev.obrienlabs.performance.nbi;

import java.util.List;
import java.util.stream.Collectors;
import java.util.stream.IntStream;
import java.util.stream.LongStream;

/**
 * Architecture
 * map the search space by interleaved UOW (1,3,5,7) - to 4 threads
 * reduce the result by comparing thread local maximums
 */
public class Collatz {
	

	private long globalMaxValue = 1L;
	private long globalMaxPath = 1L;

	private long secondsLast = System.currentTimeMillis();
	
	
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
			// optimize
			current = (current >> 1) + current  + 1L;
			//current = (current << 1) + current + 1L
			path++;
			// check limits
			if (current > maxValue) {
				maxValue = current;
			}
		}

		path++;

		// check completion of this number
		if (current < 2L) {
			// check limits
			if (maxValue > globalMaxValue) {
				globalMaxValue = maxValue;
				System.out.println("m0: " + oddSearchCurrent + " p: " + path + " m: " + (maxValue << 1) + " ms: " 
						+ (System.currentTimeMillis() - secondsLast) + " dur: " + ((System.currentTimeMillis() - secondsStart) / 1000));
				secondsLast = System.currentTimeMillis();
				result = true;
				//result = Long.valueOf(current);
			}
			if (path > globalMaxPath) {
				globalMaxPath = path;
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
		long current = oddSearchCurrent;
		long path = 0L;
		long maxValue = 1L;

		
		long searchBits = 32;
		long batchBits = 5;
		long batches = 1 << batchBits;
		long threadBits = searchBits - batchBits;
		long threads = 1 << threadBits;
		for (long part = 0; part < batches ; part++) {
			
			// generate a limited collection for the search space - 32 is a good
			System.out.println("Searching: " + searchBits + " space, batch " + part + " of " 
					+ batches + " with " + threadBits +" bits of " + threads + " threads"  );
			List<Long> oddNumbers = LongStream.range(1L + (part * threads), (1 + part) * threads)
					.boxed()
					.collect(Collectors.toList());
			
			// filter on max value or path
			List<Long> results = oddNumbers
				.parallelStream()
				.filter(num -> isCollatzMax(num.longValue(), secondsStart))
				.collect(Collectors.toList());

			results.stream().sorted().forEach(x -> System.out.println(x));
		}
	}

	public static void main(String[] args) {
		System.out.println("Collatz multithreaded 2025 michael at obrienlabs.dev");
		Collatz collatz = new Collatz();

		long oddSearchStart = 1L;        // must be odd
		long oddSearchEnd = 4294967295L; //18446744073709551615 // must be odd
		long oddSearchIncrement = 2L;
		long oddSearchCurrent = 1L;
		long secondsStart = System.currentTimeMillis();
		/**
		  if even divide by 2, if odd multiply by 3 and add 1
		  or for odd numbers do 2 steps to optimize (n + n/2 + 1) - because we truncate divides
		  6% speed up for Java, 20% for C, 6% for Go
		*/
		for(oddSearchCurrent = oddSearchStart; oddSearchCurrent < oddSearchEnd; oddSearchCurrent += oddSearchIncrement) {
			collatz.searchCollatzParallel(oddSearchCurrent, secondsStart);
			System.out.println("completed: " + (System.currentTimeMillis() - secondsStart));
			return;
		}
		//System.out.println("completed: " + (System.currentTimeMillis() - secondsStart));
	}

}
