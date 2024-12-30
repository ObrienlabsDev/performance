package main

/**
Single threaded collatz sequence generator
https://github.com/ObrienlabsDev/performance/issues/5
*/
import "fmt"

func main() {
	fmt.Println("Collatz 2024 michael@obrienlabs.dev")

	var oddSearchStart uint64 = 1 // must be odd
	var oddSearchEnd uint64 = 184 //4674 //4073709551615 // must be odd
	var oddSearchIncrement uint64 = 2
	var oddSearchCurrent uint64 = 1
	var current uint64 = oddSearchStart
	var path = 0
	var globalMaxValue uint64 = 1
	var globalMaxPath = 1
	var maxValue uint64 = 1
	var secondsStart = 1
	var secondsCurrent = 1
	var secondsLast = 1

	/**
	  if odd divide by 2, if event multiply by 3 and add 1
	*/
	for oddSearchCurrent = oddSearchStart; oddSearchCurrent < oddSearchEnd; oddSearchCurrent += oddSearchIncrement {
		current = oddSearchCurrent
		path = 1
		maxValue = 1

		for {
			if current%2 == 0 {
				current = current >> 1
			} else {
				current = current<<1 + current + 1
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
					fmt.Println("m0:", oddSearchCurrent, "p:", path, "m:", maxValue, "sec:", (secondsCurrent - secondsLast), "dur:", secondsCurrent-secondsStart)
				}
				if path > globalMaxPath {
					globalMaxPath = path
					fmt.Println("mp:", oddSearchCurrent, "p:", path, "m:", maxValue, "sec:", (secondsCurrent - secondsLast), "dur:", secondsCurrent-secondsStart)
				}
				break
			}
		}
	}
	fmt.Println("completed: ", secondsCurrent-secondsStart)
}
