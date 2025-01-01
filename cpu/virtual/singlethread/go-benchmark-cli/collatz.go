package main

/**
Single threaded collatz sequence generator
https://github.com/ObrienlabsDev/performance/issues/5
*/
import (
	"fmt"
	"time"
)

func main() {
	fmt.Println("Collatz 2024 michael obrienlabs.dev")

	var oddSearchStart uint64 = 1        // must be odd
	var oddSearchEnd uint64 = 4294967295 //18446744073709551615 // must be odd
	var oddSearchIncrement uint64 = 2
	var oddSearchCurrent uint64 = 1
	var current uint64 = oddSearchStart
	var path = 0
	var globalMaxValue uint64 = 1
	var globalMaxPath = 1
	var maxValue uint64 = 1
	var secondsStart = time.Now()
	var secondsLast = time.Now()

	/**
	  if even divide by 2, if odd multiply by 3 and add 1
	  or for odd numbers do 2 steps to optimize (n + n/2 + 1) - because we truncate divides
   	  6% speed up for Java, 20% for C, 6% for Go
	*/
	for oddSearchCurrent = oddSearchStart; oddSearchCurrent < oddSearchEnd; oddSearchCurrent += oddSearchIncrement {
		current = oddSearchCurrent
		path = 0
		maxValue = 1

		for {
			if current%2 == 0 {
				current = current >> 1
			} else {
				//current = current<<1 + current + 1
				current = current >> 1 + current + 1
				path++
				// check limits
				if current > maxValue {
					maxValue = current
				}
			}

			path++

			// check completion of this number
			if current < 2 {
				// check limits
				if maxValue > globalMaxValue {
					globalMaxValue = maxValue
					fmt.Println("m0:", oddSearchCurrent, "p:", path, "m:", (maxValue << 1), "ms:", time.Since(secondsLast).Milliseconds(), "dur:", time.Since(secondsStart).Seconds())
					secondsLast = time.Now()
				}
				if path > globalMaxPath {
					globalMaxPath = path
					fmt.Println("mp:", oddSearchCurrent, "p:", path, "m:", (maxValue << 1), "ms:", time.Since(secondsLast).Milliseconds(), "dur:", time.Since(secondsStart).Seconds())
					secondsLast = time.Now()
				}
				break
			}
		}
	}
	fmt.Println("completed: ", time.Since(secondsStart))
}
