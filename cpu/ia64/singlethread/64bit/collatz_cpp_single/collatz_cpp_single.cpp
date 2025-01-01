// collatz_cpp_single.cpp : This file contains the 'main' function. Program execution begins and ends there.
//

#include <iostream>
//#include "stdafx.h"
//#include <inttypes.h>
#include <time.h>
#include <stdio.h>

unsigned __int64 maxPath;
unsigned __int64 path;

// use long long 64 bit word
// http://en.wikipedia.org/wiki/Integer_(computer_science)#Common_integral_data_types
// http://en.wikipedia.org/wiki/Bignum
// http://en.wikipedia.org/wiki/Sch%C3%B6nhage%E2%80%93Strassen_algorithm
// http://clc-wiki.net/wiki/the_C_Standard
// http://www.open-std.org/jtc1/sc22/wg14/www/docs/n1124.pdf

__int64 hailstoneMax(__int64 start) {
    __int64 maxNumber = 0;
    __int64 num = start;
    __int64 path = 0;
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
    __int64 num = 27;
    //unsigned long long num = 1;
    __int64 maxNumber = 0;
    __int64 newMax = 0;
    unsigned long long path = 0;
    unsigned long long maxPath = 0;
    __int64 MAX = (1 << 30); // dont use long long
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
    printf("time: %ul", secondsStart);

    printf("%llu: \n", MAXBIT);
    printf("%llu: %llu : %i %llu\n", i0, max0, path, searchEnd);
    for (;;) {
        current0 = i0;
        max0 = 0;
        path = 0;

        if (i0 > searchEnd) {
            printf("Completed: %i\n", time(NULL) - secondsStart);
            break;
        }

        while (!(current0 == 1)) {
            if (current0 % 2 == 0) {
                current0 = current0 >> 1;
            } else {
                current0 = (current0 << 1) + current0 + 1;
                if (current0 > max0) {
                    max0 = current0;
                }
            }
            path++;
        }
        if (maxValue0 < max0) {
            maxValue0 = max0;
            secondsCurrent = (time(NULL));
            printf("m0: %llu p: %i m: %llu ms: %i dur: %i\n", i0, path, max0, 
                (secondsCurrent - secondsLast), secondsCurrent - secondsStart);
            secondsLast = time(NULL);
        }

        if (maxPath < path) {
            maxPath = path;
            secondsCurrent = (time(NULL));
            printf("mp: %llu p: %i m: %llu ms: %i dur: %i\n", i0, path, max0, 
                (secondsCurrent - secondsLast), secondsCurrent - secondsStart);
            secondsLast = time(NULL);
        }
        i0 += 2;
    }
}




int main(int argc, char* argv[]) {
    printf("\nCollatz Sequence\n");
    getSequence64Bench();
    return 0;
}

