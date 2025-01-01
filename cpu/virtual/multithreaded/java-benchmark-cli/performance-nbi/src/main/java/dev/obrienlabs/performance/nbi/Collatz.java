package dev.obrienlabs.performance.nbi;

public class Collatz {
	

	private long globalMaxValue = 1L;
	private long globalMaxPath = 1L;

	private long secondsLast = System.currentTimeMillis();
	
	public void searchCollatz(long oddSearchCurrent, long secondsStart) {
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
				}
				if (path > globalMaxPath) {
					globalMaxPath = path;
					System.out.println("mp: " + oddSearchCurrent + " p: " + path + " m: " + (maxValue << 1) + " ms: " 
							+ (System.currentTimeMillis() - secondsLast) + " dur: " + ((System.currentTimeMillis() - secondsStart) / 1000));
					secondsLast = System.currentTimeMillis();
				}
				break;
			}
		}
		return;
		
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
			collatz.searchCollatz(oddSearchCurrent, secondsStart);
		}
		System.out.println("completed: " + (System.currentTimeMillis() - secondsStart));
	}

}
