package main

/**
Single threaded 64 bit collatz sequence generator
https://github.com/ObrienlabsDev/performance/issues/5

Michael O'Brien 2024 michael at obrienlabs.dev
*/
import (
	"fmt"
	"runtime"
	"time"
)

// global as primitives are pass by value
var globalMaxValue uint64 = 1
var globalMaxPath = 1
var secondsLast = time.Now() // keep global for now

func collatz(oddSearchCurrent uint64, secondsStart time.Time) {
	var current uint64 = oddSearchCurrent
	var path = 0
	var maxValue uint64 = 1
	/**
		  if even divide by 2, if odd multiply by 3 and add 1
		  or for odd numbers do 2 steps to optimize (n + n/2 + 1) - because we truncate divides
	   	  6% speed up for Java, 20% for C, 6% for Go
	*/
	for {
		if current%2 == 0 {
			current = current >> 1
		} else {
			//current = current<<1 + current + 1
			current = current>>1 + current + 1
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
				fmt.Println("m0:", oddSearchCurrent, "p:", path, "m:", (maxValue << 1), "ms:",
					time.Since(secondsLast).Milliseconds(), "dur:", time.Since(secondsStart).Seconds())
				secondsLast = time.Now()

			}
			if path > globalMaxPath {
				globalMaxPath = path
				fmt.Println("mp:", oddSearchCurrent, "p:", path, "m:", (maxValue << 1), "ms:",
					time.Since(secondsLast).Milliseconds(), "dur:", time.Since(secondsStart).Seconds())
				secondsLast = time.Now()
			}
			break
		}
	}

}

func collatzSearch(secondsStart time.Time) {
	var oddSearchStart uint64 = 1        // must be odd
	var oddSearchEnd uint64 = 4294967295 //18446744073709551615 // must be odd
	var oddSearchIncrement uint64 = 2
	var oddSearchCurrent uint64 = 1

	/**
		  if even divide by 2, if odd multiply by 3 and add 1
		  or for odd numbers do 2 steps to optimize (n + n/2 + 1) - because we truncate divides
	   	  6% speed up for Java, 20% for C, 6% for Go
	*/
	for oddSearchCurrent = oddSearchStart; oddSearchCurrent < oddSearchEnd; oddSearchCurrent += oddSearchIncrement {
		collatz(oddSearchCurrent, secondsStart)
	}
}

func main() {
	fmt.Println("Collatz 2024 michael obrienlabs.dev")
	var secondsStart = time.Now()

	runtime.GOMAXPROCS(1)

	collatzSearch(secondsStart)

	fmt.Println("completed: ", time.Since(secondsStart))
}
