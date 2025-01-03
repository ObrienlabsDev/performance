package dev.obrienlabs.performance.nbi;

import java.util.List;
import java.util.stream.Collectors;
import java.util.stream.LongStream;
import java.math.BigInteger;

/**
 * 20250101
 * Michael O'Brien michael at obrienlabs.dev
 * 
 * Architecture
 * map the search space by interleaved UOW (1,3,5,7) - to 4 threads
 * reduce the result by comparing thread local maximums
 * 
 * 20250102 - move from 64 bit long to 64 bit BigInteger
 */
public class CollatzBigInteger {
	
	private long secondsLast = System.currentTimeMillis();
	private static BigInteger ONE = BigInteger.ONE;
	private static BigInteger TWO = BigInteger.TWO;
	private BigInteger globalMaxValue = ONE;
	private long globalMaxPath = 1L;
	
	public boolean isCollatzMax(BigInteger oddSearchCurrent, long secondsStart) {
		boolean result = false;
		//Long result = BigInteger.ZERO;
		BigInteger current = oddSearchCurrent;
		long path = 0L;
		BigInteger maxValue = ONE;
		
		for (;;) {
			/**
			  if even divide by 2, if odd multiply by 3 and add 1
			  or for odd numbers do 2 steps to optimize (n + n/2 + 1) - because we truncate divides
			  6% speed up for Java, 20% for C, 6% for Go
			*/
			if (current.testBit(0)) {
				current = (current.shiftRight(1)).add(current).add(ONE); // optimized
				path++;
				if (current.compareTo( maxValue) > 0) { // check limits
					maxValue = current;
				}
			} else {
				current = current.shiftRight(1);
			}

			path++;

			// check completion of this number
			if (current.compareTo(TWO) < 0) {
				// check limits
				if (maxValue.compareTo(globalMaxValue) > 0) {
					globalMaxValue = maxValue.shiftLeft(1); // double this n(3/2)
					System.out.println("m0: " + oddSearchCurrent + " p: " + path + " m: " + maxValue.shiftLeft(1) + " ms: " 
						+ (System.currentTimeMillis() - secondsLast) + " dur: " + ((System.currentTimeMillis() - secondsStart) / 1000));
					secondsLast = System.currentTimeMillis();
					result = true;
					//result = Long.valueOf(current);
				}
				if (path > globalMaxPath) {
					globalMaxPath = path;
					System.out.println("mp: " + oddSearchCurrent + " p: " + path + " m: " + maxValue.shiftLeft(1) + " ms: " 
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
	
	public void searchCollatzParallel(BigInteger oddSearchCurrent, long secondsStart) {
		long batchBits = 12; // adjust this based on the chip architecture 
		
		long searchBits = 32;
		long batches = 1 << batchBits;
		long threadBits = searchBits - batchBits;
		long threads = 1 << threadBits;
		
		System.out.println("Searching: " + searchBits + " space, batch " + "0" + " of " 
				+ batches + " with " + threadBits +" bits of " + threads + " threads"  );
		
		for (long part = 0; part < (batches + 1) ; part++) {	
			// generate a limited collection (CopyOnWriteArrayList not required as r/o) for the search space - 32 is a good
			List<Long> oddNumbers = LongStream
					.range(1L + (part * threads), ((1 + part) * threads) - 1)
					.filter(x -> x % 2 != 0) // TODO: find a way to avoid this filter using range above
					.boxed()
					.collect(Collectors.toList());
			
			// filter on max value or path
			List<BigInteger> results = oddNumbers
				.parallelStream()
				.map(n -> BigInteger.valueOf(n))
				.filter(num -> isCollatzMax(num, secondsStart))
				.collect(Collectors.toList());

			results.stream().sorted().forEach(x -> System.out.println(x));
		}
		System.out.println("last number: " + ((1 + (batches) * threads) - 1));
	}

	public static void main(String[] args) {
		System.out.println("Collatz multithreaded 2025 michael at obrienlabs.dev");
		CollatzBigInteger collatz = new CollatzBigInteger();

		BigInteger oddSearchCurrent = ONE;
		long secondsStart = System.currentTimeMillis();

		collatz.searchCollatzParallel(oddSearchCurrent, secondsStart);
		System.out.println("completed: " + (System.currentTimeMillis() - secondsStart));
	}

}
