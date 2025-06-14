//
//  main.c
//  c-arm64-benchmark-cli-64bit
//
//  Created by Michael O'Brien on 2025/5/31.
//

#include <stdio.h>
#include <time.h>

//unsigned int64_t maxPath;
//unsigned int64_t path;


// use long long 64 bit word
// http://en.wikipedia.org/wiki/Integer_(computer_science)#Common_integral_data_types
// http://en.wikipedia.org/wiki/Bignum
// http://en.wikipedia.org/wiki/Sch%C3%B6nhage%E2%80%93Strassen_algorithm
// http://clc-wiki.net/wiki/the_C_Standard
// http://www.open-std.org/jtc1/sc22/wg14/www/docs/n1124.pdf

int64_t hailstoneMax(int64_t start) {
    int64_t maxNumber = 0;
    int64_t num = start;
    int64_t path = 0;
    while (num > 4) {
        //printf("%I64d ", maxNumber);
        if ((num % 2) > 0) {
            //num = (num >> 1) + num + 1; // odd (combined 2-step odd/even = 30% speedup
            num = (num << 1) + num + 1; // odd
        }
        else {
            num >>= 1; // even
        }
        if (num > maxNumber) {
            maxNumber = num;
        }
        path++;
    }
    return maxNumber;
}


void getSequence64() {
    int64_t num = 27;
    //unsigned long long num = 1;
    int64_t maxNumber = 0;
    int64_t newMax = 0;
    unsigned long long path = 0;
    unsigned long long maxPath = 0;
    int64_t MAX = (1 << 30); // dont use long long
    while (1) {//num < MAX) {
        newMax = hailstoneMax(num);
        if (newMax > maxNumber) {
            printf("\n%I64d,\t%I64d", num, newMax);
            maxNumber = newMax;
            //printf("\n%d,\t%I64d",num,maxNumber); // or I64u, %llu (do not work properly)
        }
        num += 2;
    }
}

/* 20241229 */
void getSequence64Bench() {
    unsigned long long searchEnd = 4294967296;//  (1L << 32) - 1; // overflow to 64 bits
    unsigned long long current0 = 0; // no uint64_t typedef
    unsigned long long maxValue0 = 0;
    //unsigned long long MAXBIT = LLONG_MAX + 1;//9223372036854775807llu;//18446744073709551615llu >> 1;//16384;// * 65536;// * 65536;// * 65536;
    unsigned long long MAXBIT = 9223372036854775808;
    int maxPath = 0;
    int path = 0;
    unsigned long long max0 = 0;//7073134427238031588 - 2; // 64 bit unsigned integer, like Java's long
     // 1,980,976,057,694,848447 // record 88 61 bits 125 max 64,024,667,322,193,133,530,165,877,294,264,738,020
    //unsigned long long i0 = 534136224795llu;//446559217279;//1410123943;//77031;//27;
    unsigned long long i0 = 3;//1980976057694848447llu;// path 1475 446559217279llu;//1410123943;//77031;//27;
    // 470784170169173952:7073134427238031588: 1475

    time_t secondsStart;
    time_t secondsLast;
    time_t secondsCurrent;

    secondsStart = time(NULL);
    secondsLast = time(NULL);
    secondsCurrent = time(NULL);
    printf("time: %time_t", secondsStart);

    printf("%llu: \n", MAXBIT);
    printf("%llu: %llu : %i %llu\n", i0, max0, path, searchEnd);
    for (;;) {
        current0 = i0;
        max0 = 0;
        path = 0;

        if (i0 > searchEnd) {
            printf("Completed: %time_t\n", time(NULL) - secondsStart);
            break;
        }

        while (!(current0 == 1)) {
            if (current0 % 2 == 0) {
                current0 = current0 >> 1;
            } else {
                // 21% optimize odd+even together - needs a x2 on max height milestones later
                // When we have an odd number, the next step is usually 3n + 1 applied to the current value.However, the number resulting from 3n + 1 will always be positive - which will require at least one divide by 2. If we combine the double step optimization with the fact that a shift right(or divide by 2) is always floor truncated(where the 1 / 2 is removed on an odd number).If we combine the floor with an implicit round up(ceil) by adding 1 (where for example 27 / 2 = 13.5 = 13 rounded, with + 1 = 14) - we have the following math...
                // (3n + 1) / 2 = 3 / 2 * n + 1 / 2, where we drop the 1 / 2 due to rounding on a shift right.We then have 3 / 2 * n which is also n + n / 2. We add 1 to this to get a round up(it will hold as we only perform this round up for odd numbers) - of - 1 + n + n / 2.
                // optimized
                current0 = (current0 >> 1) + current0 + 1;
                path++; // path is 2 for this single op
                // not optimized
                //current0 = (current0 << 1) + current0 + 1;

                if (current0 > max0) {
                    max0 = current0;
                }
            }
            path++;
        }
        if (maxValue0 < max0) {
            maxValue0 = max0;
            secondsCurrent = (time(NULL));
            // optimized
            printf("m0: %llu p: %i m: %llu ms: %time_t dur: %time_t\n", i0, path, max0 << 1,
                (secondsCurrent - secondsLast), secondsCurrent - secondsStart);
            // not optimized
            //printf("m0: %llu p: %i m: %llu ms: %i dur: %i\n", i0, path, max0,
            //    (secondsCurrent - secondsLast), secondsCurrent - secondsStart);
            secondsLast = time(NULL);
        }

        if (maxPath < path) {
            maxPath = path;
            secondsCurrent = (time(NULL));
            // optimized
            printf("mp: %llu p: %i m: %llu ms: %time_t dur: %time_t\n", i0, path, max0 << 1,
                (secondsCurrent - secondsLast), secondsCurrent - secondsStart);
            // not optimized
            //printf("mp: %llu p: %i m: %llu ms: %i dur: %i\n", i0, path, max0,
            //    (secondsCurrent - secondsLast), secondsCurrent - secondsStart);
            secondsLast = time(NULL);
        }
        i0 += 2;
    }
}

int main(int argc, const char* argv[]) {
    printf("\nCollatz Sequence\n");
    getSequence64Bench();
    return 0;
}



