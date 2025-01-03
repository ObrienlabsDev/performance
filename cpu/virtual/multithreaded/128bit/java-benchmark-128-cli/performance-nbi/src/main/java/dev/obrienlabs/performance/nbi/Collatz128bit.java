package dev.obrienlabs.performance.nbi;

import java.math.BigInteger;
import java.util.List;
import java.util.concurrent.atomic.AtomicLong;
import java.util.stream.Collectors;
import java.util.stream.LongStream;

import dev.obrienlabs.performance.nbi.math.ULong128;
import dev.obrienlabs.performance.nbi.math.ULong128Impl;

/**
 * 20250101
 * Michael O'Brien michael at obrienlabs.dev
 * 
 * Architecture
 * map the search space by interleaved UOW (1,3,5,7) - to 4 threads
 * reduce the result by comparing thread local maximums
 * 20250102: refactor for 128 bit native 
 * Before refactor: m4max speed: 55sec
 */
public class Collatz128bit {
	
	private long secondsLast = System.currentTimeMillis();
	
	private ULong128 globalMaxValue = new ULong128Impl(1L);
	private ULong128 globalMaxPath = new ULong128Impl(1L);
	
	
	public boolean isCollatzMax(ULong128 oddSearchCurrent, long secondsStart) {
		boolean result = false;
		//Long result = 0L;
		ULong128 current = oddSearchCurrent;
		long path = 0L;
		long maxValue = 1L;
		
		for (;;) {	
			/**
			  if even divide by 2, if odd multiply by 3 and add 1
			  or for odd numbers do 2 steps to optimize (n + n/2 + 1) - because we truncate divides
			  6% speed up for Java, 20% for C, 6% for Go
			*/
			if (current.isEven()) {
				current = current.shiftRight(1);
			} else {
				current = current.shiftRight(1).add(current).add(1L); // optimize
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
				+ batches + " with " + threadBits +" bits of " + threads + " threads"  );
		
		for (long part = 0; part < (batches + 1) ; part++) {	
			// generate a limited collection (CopyOnWriteArrayList not required as r/o) for the search space - 32 is a good
			List<ULong128> oddNumbers = LongStream
					.range(1L + (part * threads), ((1 + part) * threads) - 1)
					.filter(x -> x % 2 != 0) // TODO: find a way to avoid this filter using range above
					.boxed()
					//.map(n -> ULong128Impl.ONE)
					.map(ULong128Impl::new)
					.collect(Collectors.toList());
			
			// filter on max value or path
			List<ULong128> results = oddNumbers
				.parallelStream()
				//.map(n -> ULong128)
				
				.filter(num -> isCollatzMax(num, secondsStart))
				.collect(Collectors.toList());

			results.stream().sorted().forEach(x -> System.out.println(x));
		}
		System.out.println("last number: " + ((1 + (batches) * threads) - 1));
	}

	public static void main(String[] args) {
		System.out.println("Collatz multithreaded 2025 michael at obrienlabs.dev");
		Collatz128bit collatz = new Collatz128bit();

		long oddSearchCurrent = 1L;
		long secondsStart = System.currentTimeMillis();

		collatz.searchCollatzParallel(oddSearchCurrent, secondsStart);

		System.out.println("completed: " + (System.currentTimeMillis() - secondsStart));
	}

}
