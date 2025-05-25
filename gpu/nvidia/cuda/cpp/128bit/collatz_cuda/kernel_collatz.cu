
#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include <iostream>
#include <time.h>
#include <omp.h>

/**
* Michael O'Brien 20241223
* michael at obrienlabs.dev
* 128 bit version
* Collatz sequence running on NVidia GPUs like the RTX-3500 ada,A4000,A4500,4090 ada and A6000
* http://www.ericr.nl/wondrous/pathrecs.html
* https://github.com/ObrienlabsDev/performance
* https://github.com/obrienlabs/benchmark/blob/master/ObjectiveC/128bit/main.m
* https://github.com/obrienlabs/benchmark/blob/master/collatz_vs10/collatz_vs10/collatz_vs10.cpp
* https://github.com/ObrienlabsDev/cuda/blob/main/add_example/kernel_collatz.cu
* https://github.com/ObrienlabsDev/collatz/blob/main/src/main/java/dev/obrienlabs/collatz/service/CollatzUnitOfWork.java
*/

__global__ void collatzCUDAKernel(/*unsigned long long* _input1, */ unsigned long long* _input0,
    unsigned long long* _output1, unsigned long long* _output0, unsigned int* _path, int threads)
{
    const unsigned long long MAXBIT = 9223372036854775808ULL;
    const unsigned long long MAX64 = 18446744073709551615ULL;
    // Calculate this thread's index
    int threadIndex = blockDim.x * blockIdx.x + threadIdx.x;

    // Check boundary (in case N is not a multiple of blockDim.x)
    unsigned int path = 0;
    unsigned long long max0 = 0ULL;
    unsigned long long current0 = 0ULL;
    unsigned long long max1 = 0ULL;
    unsigned long long current1 = 0ULL;
    unsigned long long temp0_shift = 0ULL;
    unsigned long long temp0_add = 0ULL;

    if (threadIndex < threads) {
            max0 = _input0[threadIndex];
            current0 = _input0[threadIndex];
            do {
                //_path[threadIndex] += 1;
                path += 1;
                // both even odd include a shift right - but 128 bit 2 bit carry math is required for large numbers at the 64 bit boundary
                if (current0 % 2ULL == 0) { // even
                    current0 = current0 >> 1;
                    // shift high byte if not odd (we already have a 0 in the MSB of the low word - no overflow will occur
                    if (current1 % 2ULL != 0) {
                        // add carry to avoid - overflow during the msb add to the low word
                        current0 += MAXBIT; // check overflow - will be none
                    }
                    current1 = current1 >> 1;
                } else { // odd
                    // odd n << 1 + n + 1
                    // use combined odd/even (n >> 1) + ceil(n) + 1 - only if 128 2 bit carry handling between
                    // do only 128-64 bit 3n part of 3n+1 (don't worry about overflow past 128bit into 256 bit space until we get past 64 bit inputs)
                    current1 *= 3ULL; // HIGH (3N)
                
                    // LOW (3N + 1) with 2 bit overflow
                    temp0_shift = (current0 << 1) + 1ULL; // shift first without bit0 carry in (do add n later)
                    // if lt - we have overflow
                    if (!(current0 < MAXBIT)) {//temp0_shift < current0
                        current1 += 1ULL; // add overflow carry
                    }

                    // add n step for odd - separate to break out possible 2 bit 64 bit boundary overflow
                    temp0_add = temp0_shift + current0;
                    if (temp0_add < current0) { // check shift left along with +1 instead of 
                        current1 += 1ULL; // add overflow carry
                    }

                    current0 = temp0_add;
                    // check for max (if combined odd/even mult by 2)
                    if (max1 < current1) {
                        max1 = current1;
                        max0 = current0;
                    } else {
                        if (max1 == current1) {
                            if (max0 < current0) {
                                max0 = current0;
                            }
                        }
                    }
                }
            } while (!((current0 == 1ULL) && (current1 == 0ULL)));
            // #31 move max copy inside the thread if check (to avoid concurrency issues)
            _output0[threadIndex] = max0;
            _output1[threadIndex] = max1;
            _path[threadIndex] = path;
    }
}

void singleGPUSearch() {
    unsigned long long MAXBIT = 9223372036854775808;
    unsigned int path = 0;
    int deviceCount = 0;
    int dualDevice = 0;
    cudaGetDeviceCount(&deviceCount);
    printf("%d CUDA devices found - reallocating\n", deviceCount);
    if (deviceCount > 1) {
        dualDevice = 1;
    }

    const unsigned long long oddOffsetOptimization = 2ULL;
    const int dev0 = 0;
    const unsigned long long threadsPerBlock = 512ULL;// 128;// 128; 128=50%, 256=66 on RTX-3500
    unsigned long long cores = 5120ULL;// (argc > 1) ? atoi(argv[1]) : 5120; // get command

    // variables
    // keep these 2 in sync
    unsigned int threadsPower = 16;//20;// 16; // 15
    const unsigned long long threads = 7168 * 4 + 6144;// 40960;// 7168 * 2;// 40960;// 7168 * 5;// 32768; // maximize threads below 64k
    // 43008 crash rtx-3500
    // diff should be 31 bits (minus oddOffsetOptimization)
    unsigned int startSequencePower = 39;  // do not use 0
    unsigned int endSequencePower = 64; 

    // derived
    unsigned long long startSequenceNumber = (1ULL << startSequencePower) + 1ULL;
    unsigned long long endSequenceNumber = (1ULL << endSequencePower) - 1ULL;
    printf("endSequenceNumber: %llu\n", endSequenceNumber);
    // Number of blocks = ceiling(N / threadsPerBlock)
    unsigned int blocks = 1 * ((threads / threadsPerBlock));// +threadsPerBlock - 1) / threadsPerBlock);
    size_t size = threads * sizeof(unsigned long long);
    size_t sizeInt = threads * sizeof(unsigned int);
    unsigned long long globalMaxValue0 = startSequenceNumber;
    unsigned long long globalMaxStart0 = startSequenceNumber;
    unsigned long long globalMaxValue1 = 0ULL;
    unsigned long long globalMaxStart1 = 0ULL;
    unsigned long long iterations = (endSequenceNumber - startSequenceNumber) / oddOffsetOptimization;// *((1ULL << (endSequencePower - 32)));
    unsigned long long batchNumberPower = (endSequencePower - startSequencePower) - threadsPower;
    unsigned long long batchNumber = iterations / threads; // 1ULL << batchNumberPower;
    printf("BatchNumberPower: %llu\n", batchNumberPower);
    printf("BatchNumber: %llu\n", batchNumber);
    printf("Iterations: %llu\n", iterations);

    // Host arrays
    unsigned long long host_input0[threads];
    //unsigned long long host_input1[threads];
    unsigned long long host_result0[threads] = { 0ULL };
    unsigned long long* device_input0 = nullptr;
    unsigned long long* device_output0 = nullptr;
    // for 128 not 2nd GPU
    //unsigned long long* device_input1 = nullptr;
    unsigned long long* device_output1 = nullptr;
    unsigned int* device_path = nullptr;
    unsigned int host_path[threads] = { 0 };
    unsigned long long host_result1[threads] = { 0ULL };

    time_t timeStart, timeEnd;
    double timeElapsed;
    time(&timeStart);

    // Allocate memory on the GPU
    printf("array allocation bytes per GPU: %d * %d is %d maxSearch: %llu to %llu\n", sizeof(unsigned long long) * 2, threads, size, startSequenceNumber, endSequenceNumber);
    cudaSetDevice(dev0);
    cudaMalloc((void**)&device_input0, size);
    //cudaMalloc((void**)&device_input1, size);
    cudaMalloc((void**)&device_output0, size);
    cudaMalloc((void**)&device_output1, size);
    cudaMalloc((void**)&device_path, sizeInt);

    // Iterations = 2 ^ (15(threads) + 16(endSequence = runs) + 1(odd multiplier))
    printf("GPU0: Iterations: %llu via (Threads: %llu * Batches: %llu * 2 (odd mult)) ThreadsPerBlock: %d Blocks: %d\n", 
        iterations, threads, batchNumber, threadsPerBlock, blocks);
    for (int batch = 0; batch < batchNumber; batch++) {
        // prepare inputs
        for (int thread = 0; thread < threads; thread++) {
            host_input0[thread] = startSequenceNumber;
            //host_input1[thread] = 0ULL;
            startSequenceNumber += oddOffsetOptimization;
            host_path[thread] = 0;
        }

        cudaMemcpy(device_input0, host_input0, size, cudaMemcpyHostToDevice);
        //cudaMemcpy(device_input1, host_input1, size, cudaMemcpyHostToDevice);
        // Launch kernel
        // kernelName<<<numBlocks, threadsPerBlock>>>(parameters...);
        collatzCUDAKernel << <blocks, threadsPerBlock >> > (/*device_input1,*/ device_input0, device_output1, device_output0, device_path, threads);

        // Wait for GPU to finish before accessing on host
        cudaDeviceSynchronize();

        // Copy result from device back to host
        cudaMemcpy(host_result0, device_output0, size, cudaMemcpyDeviceToHost);
        cudaMemcpy(host_result1, device_output1, size, cudaMemcpyDeviceToHost);
        cudaMemcpy(host_path, device_path, sizeInt, cudaMemcpyDeviceToHost);
        // process reesults: parallelize with OpenMP // no effect yet
        omp_set_num_threads(threads);
        #pragma omp parallel for reduction (+:globalMaxValue0, globalMaxValue1)
            for (int thread = 0; thread < threads; thread++) {
                path = host_path[thread];
                if (host_result1[thread] > globalMaxValue1) {
//#pragma omp critical
                   // {
                        globalMaxValue0 = host_result0[thread];
                        globalMaxValue1 = host_result1[thread];
                        globalMaxStart0 = host_input0[thread];
                        globalMaxStart1 = 0ULL;// host_input1[thread];

                        time(&timeEnd);
                        timeElapsed = difftime(timeEnd, timeStart);
                        std::cout << "GPU01:Sec: " << timeElapsed << " path: " << path << " GlobalMax: " << globalMaxStart1 << ":" << globalMaxStart0 << ": " << globalMaxValue1
                            << ":" << globalMaxValue0 << " last search: " << startSequenceNumber << "\n";
                    //}
                }
                else {
                    // handle only lsb gt
                    if (host_result1[thread] == globalMaxValue1) {
                        if (host_result0[thread] > globalMaxValue0) {
//#pragma omp critical 
                            //{
                                globalMaxValue0 = host_result0[thread];
                                globalMaxStart0 = host_input0[thread];
                                globalMaxStart1 = 0ULL;// host_input1[thread];

                                time(&timeEnd);
                                timeElapsed = difftime(timeEnd, timeStart);
                                std::cout << "GPU00:Sec: " << timeElapsed << " path: " << path << " GlobalMax: " << globalMaxStart1 << ":" << globalMaxStart0 << " : " << globalMaxValue1
                                    << ":" << globalMaxValue0 << " last search: " << startSequenceNumber << "\n";
                            //}
                        }
                    }
                }

            // TODO: maxPath
        }
    }

    // Print the result for the last run
    std::cout << "collatz:\n";
    for (int i = 0; i < 20/*threads*/; i++)
    {
        std::cout << "GPU0: " << i << ": " << /*host_input1[i] <<*/ ":" << host_input0[i] << " = " << host_result1[i] << host_result0[i] << "\n";
    }

    time(&timeEnd);
    timeElapsed = difftime(timeEnd, timeStart);

    printf("duration: %.f\n", timeElapsed);
    std::cout << "Sec: " << timeElapsed << " GlobalMax: " << globalMaxStart1 << ":" << globalMaxStart0 << " : " << globalMaxValue1 
        << ":" << globalMaxValue0 << " last search : " << startSequenceNumber << "\n";

    // Free GPU memory
    cudaFree(device_input0);
    //cudaFree(device_input1);
    cudaFree(device_output0);
    cudaFree(device_output1);
    cudaFree(device_path);

    free(host_input0);
    //free(host_input1);
    free(host_result0);
    free(host_result1);
    free(host_path);
    return;
}

void dualGPUSearch() {
    int deviceCount = 0;
    int dualDevice = 0;
    cudaGetDeviceCount(&deviceCount);
    printf("%d CUDA devices found - reallocating", deviceCount);
    if (deviceCount > 1) {
        dualDevice = 1;
    }



    const unsigned long long oddOffsetOptimization = 2ULL;
    const int dev0 = 0;
    const int dev1 = 1;
    const unsigned long long threadsPerBlock = 256ULL;// 128;// 128; 128=50%, 256=66 on RTX-3500
    unsigned long long cores = 5120ULL;// (argc > 1) ? atoi(argv[1]) : 5120; // get command
    // exited with code -1073741571 any higher
    // VRAM related - cannot exceed 32k threads for dual 12g RTX-3500 - check 4090

    // variables
    // keep these 2 in sync
    unsigned int threadsPower = 14;
    const unsigned long long threads = 16384;
    // diff should be 31 bits (minus oddOffsetOptimization)
    unsigned int startSequencePower = 1;  // do not use 0
    unsigned int endSequencePower = 33;

    // derived
    unsigned long long startSequenceNumber = (1ULL << startSequencePower) + 1ULL;
    unsigned long long endSequenceNumber = (1ULL << endSequencePower) - 1ULL;
    printf("endSequenceNumber: %llu\n", endSequenceNumber);
    // Number of blocks = ceiling(N / threadsPerBlock)
    unsigned int blocks = (threads + threadsPerBlock - 1) / threadsPerBlock;
    size_t size = threads * sizeof(unsigned long long);
    unsigned long long globalMaxValue = startSequenceNumber;
    unsigned long long globalMaxStart = startSequenceNumber;
    unsigned long long iterations = (endSequenceNumber - startSequenceNumber) / oddOffsetOptimization;// +1);
    unsigned long long batchNumberPower = (endSequencePower - startSequencePower) - threadsPower;
    unsigned long long batchNumber = iterations / threads; // 1ULL << batchNumberPower;
    printf("BatchNumberPower: %llu\n", batchNumberPower);
    printf("BatchNumber: %llu\n", batchNumber);
    printf("Iterations: %llu\n", iterations);

    // Host arrays
    unsigned long long host_input0[threads];
    unsigned long long host_result0[threads] = { 0 };
    unsigned long long* device_input0 = nullptr;
    unsigned long long* device_output0 = nullptr;
    unsigned long long host_input1[threads];
    unsigned long long host_result1[threads] = { 0 };
    unsigned long long* device_input1 = nullptr;
    unsigned long long* device_output1 = nullptr;

    time_t timeStart, timeEnd;
    double timeElapsed;
    time(&timeStart);

    // Allocate memory on the GPU
    printf("array allocation bytes per GPU: %d * %d is %d maxSearch: %llu\n", sizeof(unsigned long long), threads, size, endSequenceNumber);
    cudaSetDevice(dev0);
    cudaMalloc((void**)&device_input0, size);
    cudaMalloc((void**)&device_output0, size);
    if (dualDevice > 0) {
        cudaSetDevice(dev1);
        cudaMalloc((void**)&device_input1, size);
        cudaMalloc((void**)&device_output1, size);
    }

    // GPU0: Iterations: 8388608 Threads: 31232 ThreadsPerBlock: 64 Blocks: 488
    printf("GPU0: Threads: %d ThreadsPerBlock: %d Blocks: %d\n", threads, threadsPerBlock, blocks);
    if (dualDevice > 0) {
        printf("GPU1: Threads: %d ThreadsPerBlock: %d Blocks: %d\n", threads, threadsPerBlock, blocks);
    }

    // fill out current batch
    for (int index = 0; index < endSequenceNumber; index++) {
        for (int q = 0; q < threads; q++) {
            host_input0[q] = startSequenceNumber;
            if (dualDevice > 0) {
                startSequenceNumber += oddOffsetOptimization;
                host_input1[q] = startSequenceNumber;
            }
            startSequenceNumber += oddOffsetOptimization;
        }

        cudaSetDevice(dev0);
        cudaMemcpy(device_input0, host_input0, size, cudaMemcpyHostToDevice);

        if (dualDevice > 0) {
            cudaSetDevice(dev1);
            cudaMemcpy(device_input1, host_input1, size, cudaMemcpyHostToDevice);
        }

        // Launch kernel
        cudaSetDevice(dev0);
        // kernelName<<<numBlocks, threadsPerBlock>>>(parameters...);
        //collatzCUDAKernel << <blocks, threadsPerBlock >> > (device_input0, device_output0, threads);

        if (dualDevice > 0) {
            cudaSetDevice(dev1);
        //    collatzCUDAKernel << <blocks, threadsPerBlock >> > (device_input1, device_output1, threads);
        }

        // Wait for GPU to finish before accessing on host
        cudaSetDevice(dev0);
        cudaDeviceSynchronize();
        if (dualDevice > 0) {
            cudaSetDevice(dev1);
            cudaDeviceSynchronize();
        }

        // Copy result from device back to host
        cudaMemcpy(host_result0, device_output0, size, cudaMemcpyDeviceToHost);
        if (dualDevice > 0) {
            cudaMemcpy(host_result1, device_output1, size, cudaMemcpyDeviceToHost);
        }

        // parallelize
        for (int index = 0; index < threads; index++) {
            if (host_result0[index] > globalMaxValue) {
                globalMaxValue = host_result0[index];
                globalMaxStart = host_input0[index];
                time(&timeEnd);
                timeElapsed = difftime(timeEnd, timeStart);
                std::cout << "GPU0:Sec: " << timeElapsed << " GlobalMax: " << globalMaxStart << ": " << globalMaxValue << " last search: " << startSequenceNumber << "\n";
            }
            if (dualDevice > 0) {
                if (host_result1[index] > globalMaxValue) {
                    globalMaxValue = host_result1[index];
                    globalMaxStart = host_input1[index];
                    time(&timeEnd);
                    timeElapsed = difftime(timeEnd, timeStart);
                    std::cout << "GPU1:Sec: " << timeElapsed << " GlobalMax: " << globalMaxStart << ": " << globalMaxValue << " last search: " << startSequenceNumber << "\n";
                }
            }
        }
    }

    // Print the result
    std::cout << "collatz:\n";
    for (int i = 0; i < 20/*threads*/; i++)
    {
        std::cout << "GPU0: " << i << ": " << host_input0[i] << " = " << host_result0[i] << "\n";
        if (dualDevice > 0) {
            std::cout << "GPU1: " << i << ": " << host_input1[i] << " = " << host_result1[i] << "\n";
        }
    }

    time(&timeEnd);
    timeElapsed = difftime(timeEnd, timeStart);

    printf("duration: %.f\n", timeElapsed);
    std::cout << "Sec: " << timeElapsed << " GlobalMax: " << globalMaxStart << " : " << globalMaxValue << " last search : " << startSequenceNumber << "\n";

    // Free GPU memory
    cudaSetDevice(dev0);
    cudaFree(device_input0);
    cudaFree(device_output0);
    if (dualDevice > 0) {
        cudaSetDevice(dev1);
        cudaFree(device_input1);
        cudaFree(device_output1);
    }

    free(host_input0);
    if (dualDevice > 0) {
        free(host_input1);
    }
    return;
}

void testCollatzCUDAKernel(unsigned long long _input1, unsigned long long _input0,
    unsigned long long _output1, unsigned long long _output0)//, int threads)
{
    const unsigned long long MAXBIT = 9223372036854775808ULL;
    // Calculate this thread's index
    int threadIndex = 0; //blockDim.x* blockIdx.x + threadIdx.x;

    // Check boundary (in case N is not a multiple of blockDim.x)
    int path = 0;
    unsigned long long max0 = _input0;// [threadIndex] ;
    unsigned long long current0 = _input0;// [threadIndex] ;
    unsigned long long max1 = _input1;// [threadIndex] ;
    unsigned long long current1 = _input1;// [threadIndex] ;
    unsigned long long temp0 = 0ULL;
    unsigned long long temp1 = 0ULL;
    unsigned long long temp0_shift = 0ULL;
    unsigned long long temp0_add = 0ULL;
   

   // if (threadIndex < threads) {
        path = 0;
        max0 = _input0;// [threadIndex] ;
        current0 = _input0;// [threadIndex] ;
        do {
            path += 1;
            // keep copy of n
            //temp0 = current0;
            //temp1 = current1;
            // both even odd include a shift right - but 128 bit 2 bit carry math is required for large numbers at the 64 bit boundary
            // even
            if (current0 % 2ULL == 0) {
                current0 = current0 >> 1;
                // shift high byte if not odd (we already have a 0 in the MSB of the low word - no overflow will occur
                if (current1 % 2ULL != 0) {
                    // add carry to avoid - overflow during the msb add to the low word
                    //temp0_sh = current0;
                    current0 += MAXBIT; // check overflow - will be none
                    //if (current0 < temp0_sh) {
                    //    current1 += 1ULL;
                    //}
                }
                current1 = current1 >> 1;
                printf("even: %llu:%llu\n", current1, current0);
            } else {
                // odd n << 1 + n + 1
                //path += 1; // if we combine odd/even
                // use (n >> 1) + ceil(n) + 1 - only if 128 2 bit carry handling between
                // do only 128-64 bit 3n part of 3n+1 (don't worry about overflow past 128bit into 256 bit space until we get past 64 bit inputs)
                // HIGH (3N)
                if (current0 > MAXBIT) {
                    printf("msb non-zero: %llu:%llu\n", current1, current0);
                }
                current1 *= 3ULL; 

                // LOW (3N + 1) with 2 bit overflow
                // shift first plus carry in (do add n later)
                temp0_shift = (current0 << 1) + 1ULL;
                // if lt - we have overflow
                if (!(current0 < MAXBIT)) {
                    current1 += 1ULL; // add overflow
                }

                // add n step for odd - separate to break out possible 2 bit 64 bit boundary overflow
                temp0_add = temp0_shift + current0;
                if (temp0_add < current0) {
                    current1 += 1ULL; // add overflow
                }
                current0 = temp0_add;
                
                printf("odd:  %llu:%llu\n", current1, current0);
                // check for max (if combined odd/even mult by 2)
                if (max1 < current1) {
                    max1 = current1;
                    max0 = current0;
                    printf("Max1: %llu:%llu\n", current1, current0);
                }
                else {
                    if (max1 == current1) {
                        if (max0 < current0) {
                            max0 = current0;
                            printf("Max0: %llu:%llu\n", current1, current0);
                        }
                    }
                }
            }
        } while (!((current0 == 1ULL) && (current1 == 0ULL)));

        // double max
        //unsigned long long _max1 = 0ULL;
        //unsigned long long _max0 = 0ULL;
        //_max1 = max1 << 1;
        //_max0 = max0 << 1;
        //if (!(max0 < MAXBIT)) {// _max0 < max0) {
        //    _max1 += 1ULL; // add carry
        //}
        printf("path: %llu actual max: %llu:%llu\n", path, max1, max0);// _max1, _max0 );
    //}
    _output0 = max0;
    _output1 = max1;
}

int main(int argc, char* argv[])
{
    int cores = (argc > 1) ? atoi(argv[1]) : 5120; // get command
    singleGPUSearch();
    //dualGPUSearch();
    //unsigned long long _input0 = 12327829503ULL; // 1:2275654840695500112
    unsigned long long _input0 = 23035537407ULL; // 3:13497924420419572192
    //unsigned long long _input0 = 65536ULL;
    unsigned long long _input1 = 0ULL;// 65536ULL;
    unsigned long long _output1 = 0ULL;
    unsigned long long _output0 = 0ULL;
    //testCollatzCUDAKernel(_input1, _input0, _output1, _output0);

    return 0;
}

