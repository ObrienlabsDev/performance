// collatz_cpp_single.cpp : This file contains the 'main' function. Program execution begins and ends there.
//

#include <iostream>
//#include "stdafx.h"
//#include <inttypes.h>
#include <time.h>
#include <stdio.h>

unsigned short FIRST_BIT = 127;
unsigned short number[128];
unsigned short temp[128];
unsigned short maxValue[128];
unsigned short max[128];
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

int isPowerOf2(int radix) {
    // check all digits for 0 except radix
    for (int i = 0; i < (FIRST_BIT - 1); i++) {
        if (number[i] != 0) {
            return 0;
        }
    }
    // now check radix
    if (number[radix] == 1) {
        return 1;
    }
    else {
        return 0;
    }
}

void shiftLeft(int carry) {
    for (int i = 0; i < (FIRST_BIT - 1); i++) {
        number[i] = number[i - 1];
        // overflow bit 0 is discarded
    }
    number[FIRST_BIT] = carry;
}

void shiftRight(int borrow) {
    for (int i = 0; i < (FIRST_BIT - 1); i++) {
        number[FIRST_BIT - i] = number[FIRST_BIT - 1 - i];
        // underflow bit 63 is discarded
    }
    number[0] = 0;
}

void addSelf() {
    short carry = 0;
    short temp = 0;
    for (int i = 0; i < FIRST_BIT; i++) {
        temp = number[i];
        if (number[FIRST_BIT - i] > 0) {
            number[FIRST_BIT - i] = 1;
            carry = 1;
        }
        else {
            number[FIRST_BIT - i] = 0;
            carry = 0;
        }
    } // overflow
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

/* 20241229:2256*/
void getSequence128Bench() {
    unsigned long long current0 = 0; // no uint64_t typedef
    unsigned long long current1 = 0;
    unsigned long long maxValue0 = 0;
    unsigned long long maxValue1 = 0;
    //unsigned long long MAXBIT = LLONG_MAX + 1;//9223372036854775807llu;//18446744073709551615llu >> 1;//16384;// * 65536;// * 65536;// * 65536;
    unsigned long long MAXBIT = 9223372036854775808;
    int maxPath = 0;//1475 - 2;
    int path = 0;
    unsigned long long max0 = 0;//7073134427238031588 - 2; // 64 bit unsigned integer, like Java's long
    unsigned long long max1 = 0;//470784170169173952 - 2;
    // 1,980,976,057,694,848447 // record 88 61 bits 125 max 64,024,667,322,193,133,530,165,877,294,264,738,020
    //unsigned long long i0 = 534136224795llu;//446559217279;//1410123943;//77031;//27;
    unsigned long long i0 = 3;//1980976057694848447llu;// path 1475 446559217279llu;//1410123943;//77031;//27;
    // 470784170169173952:7073134427238031588: 1475

    unsigned long long i1 = 0;
    unsigned long long temp0_sh = 0;
    unsigned long long temp0_ad = 0;
    unsigned long long temp1 = 0;

    time_t secondsStart;
    time_t secondsLast;
    time_t secondsCurrent;

    secondsStart = time(NULL);
    secondsLast = time(NULL);
    secondsCurrent = time(NULL);
    printf("time: %ul", secondsStart);

    printf("%llu: \n", MAXBIT);
    printf("%llu: %llu : %i\n", i0, max0, path);
    //for (int64_t i=27; i < 223372036854775808; i+=2) {
    for (;;) {
            current0 = i0;
            current1 = i1;
            max1 = 0;
            max0 = 0;
            path = 0;
            while (!((current0 == 1) && (current1 == 0))) {
                if (current0 % 2 == 0) {
                    current0 = current0 >> 1;
                    // shift high byte first
                    if (current1 % 2 != 0) {
                        current0 += MAXBIT;
                        //NSLog(@"u: %llu:%llu %i",current1, current0,path);
                    }
                    current1 = current1 >> 1;
                    //NSLog(@"x: %llu:%llu %i",current1, current0,path);
                }
                else {
                    temp1 = 3 * current1;// + (current1 << 1);
                    current1 = temp1;

                    // shift first - calc overflow 1
                    temp0_sh = 1 + (current0 << 1);
                    if (!(current0 < MAXBIT)) {
                        current1 = current1 + 1;
                        //NSLog(@"o1: %llu:%llu %i",current1, temp0_sh,path);

                    }
                    // add second - calc overflow 2
                    temp0_ad = temp0_sh + current0;
                    if (temp0_ad < current0) { // overflow
                        current1 = current1 + 1;
                        //NSLog(@"o2: %llu:%llu %i",current1, temp0_ad,path);
                    }
                    current0 = temp0_ad;
                    //NSLog(@"z: %llu:%llu %i",current1, current0,path);

                }
                path++;
                if (max1 < current1) {
                    max1 = current1;
                    max0 = current0;
                    //NSLog(@"m: %llu: %llu: %i",max1, max0, path);
                }
                else {
                    if (max1 == current1) {
                        if (max0 < current0) {
                            max0 = current0;
                            //NSLog(@"b: %llu: %lld: %i",max1, max0, path);
                        }
                    }
                }
            }
            //bool maxSet = false;
            if (maxValue1 < max1) {
                maxValue0 = max0;
                maxValue1 = max1;
                secondsCurrent = (time(NULL));
                printf("m1: %llu:%llu %llu:%llu: p: %i sec: %i dur: %i\n", i1, i0, max1, max0, path, (secondsCurrent - secondsLast), secondsCurrent - secondsStart);
                secondsLast = time(NULL);
            }
            else {
                if (maxValue1 == max1) {
                    if (maxValue0 < max0) {
                        maxValue0 = max0;
                        secondsCurrent = (time(NULL));
                        printf("m0: %llu:%llu %llu:%llu: p: %i sec: %i dur: %i\n", i1, i0, max1, max0, path, (secondsCurrent - secondsLast), secondsCurrent - secondsStart);
                        secondsLast = time(NULL);
                    }
                }
            }
            if (maxPath < path) {
                maxPath = path;
                secondsCurrent = (time(NULL));
                printf("mp: %llu:%llu %llu:%llu: p: %i sec: %i dur: %i\n", i1, i0, max1, max0, path, (secondsCurrent - secondsLast), secondsCurrent - secondsStart);
                secondsLast = time(NULL);
            }
            i0 += 2;
    }
}



void getSequence64Bench() {
    __int64 num = 27;
    //unsigned long long num = 1;
    __int64 maxNumber = 0;
    __int64 newMax = 0;
    unsigned long long path = 0;
    unsigned long long maxPath = 0;
    __int64 MAX = (1 << 4); // dont use long long
    unsigned long  iter1 = (1 << 6);
    unsigned long long iter2;// = (1 << 16);
    unsigned long long iter3;// = (1 << 16);
    while (iter1-- > 0) {
        printf(".");
        iter2 = (1 << 16);
        while (iter2-- > 0) {
            iter3 = (1 << 16);
            while (iter3-- > 0) {
                newMax = hailstoneMax(num);
                if (newMax > maxNumber) {
                    //printf("\n%d,%I64d,\t%I64d",iter,num, newMax);
                    //maxNumber = newMax;
                    printf("\n%d,\t%I64d", num, maxNumber); // or I64u, %llu (do not work properly)
                }
                //num += 2;
            }
        }
    }
    printf("\nfinished\n");
}

void clear() {
    for (int i = 0; i < FIRST_BIT; i++) {
        number[i] = 0;
        temp[i] = 0;
        maxValue[i] = 0;
        max[i] = 0;
        path = 0;
        maxPath = 0;
    }
}

__int64 getLong(unsigned short* bitArray) {
    __int64 number = 0;
    for (int i = 0; i < (FIRST_BIT); i++) {
        number += bitArray[i] << (FIRST_BIT - i);
    }
    return number;
}
__int64 hailstoneMax2() {
    while (!isPowerOf2(FIRST_BIT)) {
        if (number[FIRST_BIT] == 1) {
            shiftLeft(1);
            addSelf();
        }
        else {
            shiftRight(0);
        }
    }
    return getLong(number);
}

void getSequence128() {
    // initialize bits
    clear();

    __int64 num = 27;
    __int64 maxNumber = 0;
    __int64 newMax = 0;
    //unsigned long long path = 0;
    //unsigned long long maxPath = 0;
    __int64 MAX = (1 << 31) - 1; // dont use long long
    while (num < MAX) {
        printf("%I64d ", maxNumber);
        newMax = hailstoneMax2();
        if (newMax > maxNumber) {
            printf("\n%I64d,\t%I64d", num, newMax);
            maxNumber = newMax;
            //printf("\n%d,\t%I64d",num,maxNumber); // or I64u, %llu (do not work properly)
        }
        num += 2;
    }
}

int main(int argc, char* argv[]) {
    printf("\nCollatz Sequence\n");
    //getSequence128();
    //getSequence64();
    getSequence128Bench(); // 2304
    return 0;
}



/**
13900 4500

verified

2	275654	840695	500112
9	223372	36854	775808	max
18	446744	73708	1551616	*2
        1	551616	carry
18	446744	73709	551616	subtotal for 1 x 64th bit
20	722398	914404	1051728	sub
20	722398	914405	51728
20	722398	914405	51728	total

Collatz Sequence
9223372036854775808:
3: 0 : 0
m0: 0:3 0:16: 7
mp: 0:3 0:16: 7
m0: 0:7 0:52: 16
mp: 0:7 0:52: 16
mp: 0:9 0:52: 19
m0: 0:15 0:160: 17
mp: 0:19 0:88: 20
mp: 0:25 0:88: 23
m0: 0:27 0:9232: 111
mp: 0:27 0:9232: 111
mp: 0:55 0:9232: 112
mp: 0:73 0:9232: 115
mp: 0:97 0:9232: 118
mp: 0:129 0:9232: 121
mp: 0:171 0:9232: 124
mp: 0:231 0:9232: 127
m0: 0:255 0:13120: 47
mp: 0:313 0:9232: 130
mp: 0:327 0:9232: 143
m0: 0:447 0:39364: 97
m0: 0:639 0:41524: 131
mp: 0:649 0:9232: 144
m0: 0:703 0:250504: 170
mp: 0:703 0:250504: 170
mp: 0:871 0:190996: 178
mp: 0:1161 0:190996: 181
m0: 0:1819 0:1276936: 161
mp: 0:2223 0:250504: 182
mp: 0:2463 0:250504: 208
mp: 0:2919 0:250504: 216
mp: 0:3711 0:481624: 237
m0: 0:4255 0:6810136: 201
m0: 0:4591 0:8153620: 170
mp: 0:6171 0:975400: 261
m0: 0:9663 0:27114424: 184
mp: 0:10971 0:975400: 267
mp: 0:13255 0:497176: 275
mp: 0:17647 0:11003416: 278
m0: 0:20895 0:50143264: 255
mp: 0:23529 0:11003416: 281
m0: 0:26623 0:106358020: 307
mp: 0:26623 0:106358020: 307
m0: 0:31911 0:121012864: 160
mp: 0:34239 0:18976192: 310
mp: 0:35655 0:41163712: 323
mp: 0:52527 0:106358020: 339
m0: 0:60975 0:593279152: 334
mp: 0:77031 0:21933016: 350
m0: 0:77671 0:1570824736: 231
mp: 0:106239 0:104674192: 353
m0: 0:113383 0:2482111348: 247
m0: 0:138367 0:2798323360: 162
mp: 0:142587 0:593279152: 374
mp: 0:156159 0:41163712: 382
m0: 0:159487 0:17202377752: 183
mp: 0:216367 0:11843332: 385
mp: 0:230631 0:76778008: 442
m0: 0:270271 0:24648077896: 406
mp: 0:410011 0:76778008: 448
mp: 0:511935 0:76778008: 469
mp: 0:626331 0:7222283188: 508
m0: 0:665215 0:52483285312: 441
m0: 0:704511 0:56991483520: 242
mp: 0:837799 0:2974984576: 524
m0: 0:1042431 0:90239155648: 439
mp: 0:1117065 0:2974984576: 527
m0: 0:1212415 0:139646736808: 328
m0: 0:1441407 0:151629574372: 367
mp: 0:1501353 0:90239155648: 530
mp: 0:1723519 0:46571871940: 556
m0: 0:1875711 0:155904349696: 370
m0: 0:1988859 0:156914378224: 427
mp: 0:2298025 0:46571871940: 559
m0: 0:2643183 0:190459818484: 430
m0: 0:2684647 0:352617812944: 399
m0: 0:3041127 0:622717901620: 363
mp: 0:3064033 0:46571871940: 562
mp: 0:3542887 0:294475592320: 583
mp: 0:3732423 0:294475592320: 596
m0: 0:3873535 0:858555169576: 322
m0: 0:4637979 0:1318802294932: 573
mp: 0:5649499 0:1017886660: 612
m0: 0:5656191 0:2412493616608: 400
m0: 0:6416623 0:4799996945368: 483
m0: 0:6631675 0:60342610919632: 576
mp: 0:6649279 0:15208728208: 664
mp: 0:8400511 0:159424614880: 685
mp: 0:11200681 0:159424614880: 688
mp: 0:14934241 0:159424614880: 691
mp: 0:15733191 0:159424614880: 704
m0: 0:19638399 0:306296925203752: 606
mp: 0:31466383 0:159424614880: 705
mp: 0:36791535 0:159424614880: 744
m0: 0:38595583 0:474637698851092: 483
mp: 0:63728127 0:966616035460: 949
m0: 0:80049391 0:2185143829170100: 572
m0: 0:120080895 0:3277901576118580: 438
mp: 0:127456255 0:966616035460: 950
mp: 0:169941673 0:966616035460: 953
m0: 0:210964383 0:6404797161121264: 475
mp: 0:226588897 0:966616035460: 956
mp: 0:268549803 0:966616035460: 964
m0: 0:319804831 0:1414236446719942480: 592
mp: 0:537099607 0:966616035460: 965
mp: 0:670617279 0:966616035460: 986
mp: 0:1341234559 0:966616035460: 987
m0: 0:1410123943 0:7125885122794452160: 770
mp: 0:1412987847 0:966616035460: 1000
mp: 0:1674652263 0:966616035460: 1008
mp: 0:2610744987 0:966616035460: 1050
mp: 0:4578853915 0:966616035460: 1087
mp: 0:4890328815 0:319497287463520: 1131
m0: 0:8528817511 0:18144594937356598024: 726
mp: 0:9780657631 0:319497287463520: 1132
mp: 0:12212032815 0:319497287463520: 1153
mp: 0:12235060455 0:1037298361093936: 1184
m1: 0:12327829503 1:2275654840695500112: 543
mp: 0:13371194527 0:319497287463520: 1210
mp: 0:17828259369 0:319497287463520: 1213
m1: 0:23035537407 3:13497924420419572192: 836
mp: 0:31694683323 0:319497287463520: 1219
m1: 0:45871962271 4:8554672607184627540: 555
m1: 0:51739336447 6:3959152699356688744: 770
m1: 0:59152641055 8:3925412472713788616: 871
m1: 0:59436135663 11:2822204561036784392: 796
mp: 0:63389366647 0:319497287463520: 1220
m1: 0:70141259775 22:15138744166779694152: 1109
*/