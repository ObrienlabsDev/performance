package main

/**
Single threaded collatz sequence generator
https://github.com/ObrienlabsDev/performance/issues/5
*/
import "fmt"

func main() {
	fmt.Println("Collatz 2024 michael@obrienlabs.dev")

	var oddSearchStart uint64 = 1                  // must be odd
	var oddSearchEnd uint64 = 18446744073709551615 // must be odd
	var current uint64 = oddSearchStart
	var path = 1
	//var globalMaxValue uint64 = 1
	//var globalMaxPath uint64 = 1
	var maxValue uint64 = 1
	//var maxPath uint64 = 1
	var secondsStart = 1
	var secondsCurrent = 1
	var secondsLast = 1

	for current = oddSearchStart; current < oddSearchEnd; current += 2 {
		fmt.Println("mp:", current, "p:", path, "m:", maxValue, "sec:", (secondsCurrent - secondsLast), "dur:", secondsCurrent-secondsStart)
	}
}
