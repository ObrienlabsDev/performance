
#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include <iostream>
#include <time.h>

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

__global__ void collatzCUDAKernel(/*unsigned long long* _input1, */unsigned long long* _input0,
    unsigned long long* _output1, unsigned long long* _output0, int threads)
{
    const unsigned long long MAXBIT = 9223372036854775808;
    // Calculate this thread's index
    int threadIndex = blockDim.x * blockIdx.x + threadIdx.x;

    // Check boundary (in case N is not a multiple of blockDim.x)
    int path = 0;
    unsigned long long max0 = _input0[threadIndex];
    unsigned long long current0 = _input0[threadIndex];
    unsigned long long max1 = 0ULL;// _input1[threadIndex];
    unsigned long long current1 = 0ULL; //_input1[threadIndex];
    unsigned long long temp1 = 0ULL;
    unsigned long long temp0_sh = 0ULL;
    unsigned long long temp0_ad = 0ULL;

    if (threadIndex < threads) {
            path = 0;
            max0 = _input0[threadIndex];
            current0 = _input0[threadIndex];
            do {
                path += 1;
                if (current0 % 2 == 0) {
                    current0 = current0 >> 1;
                    // shift high byte if not odd
                    if (current1 % 2 != 0) {
                        current0 += MAXBIT;
                    }
                    else {
                        current1 = current1 >> 1;
                    }
                }
                else {
                    temp1 = 3 * current1;// + (current1 << 1);
                    current1 = temp1;

                    // shift first - calc overflow 1
                    temp0_sh = 1 + (current0 << 1);
                    if (!(current0 < MAXBIT)) {
                        current1 = current1 + 1;
                    }
                    // add second - calc overflow 2
                    temp0_ad = temp0_sh + current0;
                    if (temp0_ad < current0) { // overflow
                        current1 = current1 + 1;
                    }
                    current0 = temp0_ad;

                    // check for max
                    if (max1 < current1) {
                        max1 = current1;
                        max0 = current0;
                    }
                    else {
                        if (max1 == current1) {
                            if (max0 < current0) {
                                max0 = current0;
                            }
                        }
                    }
                }
            } while (!(current0 == 1) && (current1 == 0));
    }
    _output0[threadIndex] = max0;
}

void singleGPUSearch() {
    unsigned long long MAXBIT = 9223372036854775808;
    int deviceCount = 0;
    int dualDevice = 0;
    cudaGetDeviceCount(&deviceCount);
    printf("%d CUDA devices found - reallocating\n", deviceCount);
    if (deviceCount > 1) {
        dualDevice = 1;
    }

    const unsigned long long oddOffsetOptimization = 2ULL;
    const int dev0 = 0;
    const unsigned long long threadsPerBlock = 256ULL;// 128;// 128; 128=50%, 256=66 on RTX-3500
    unsigned long long cores = 5120ULL;// (argc > 1) ? atoi(argv[1]) : 5120; // get command

    // variables
    // keep these 2 in sync
    unsigned int threadsPower = 15;
    const unsigned long long threads = 32768;
    // diff should be 31 bits (minus oddOffsetOptimization)
    unsigned int startSequencePower = 1;  // do not use 0
    unsigned int endSequencePower = 32; 

    // derived
    unsigned long long startSequenceNumber = (1ULL << startSequencePower) + 1ULL;
    unsigned long long endSequenceNumber = (1ULL << endSequencePower) - 1ULL;
    printf("endSequenceNumber: %llu\n", endSequenceNumber);
    // Number of blocks = ceiling(N / threadsPerBlock)
    unsigned int blocks = (threads + threadsPerBlock - 1) / threadsPerBlock;
    size_t size = threads * sizeof(unsigned long long);
    unsigned long long globalMaxValue0 = startSequenceNumber;
    unsigned long long globalMaxStart0 = startSequenceNumber;
    unsigned long long globalMaxValue1 = 0ULL;
    unsigned long long globalMaxStart1 = 0ULL;
    unsigned long long iterations = (endSequenceNumber - startSequenceNumber) / oddOffsetOptimization;
    unsigned long long batchNumberPower = (endSequencePower - startSequencePower) - threadsPower;
    unsigned long long batchNumber = iterations / threads; // 1ULL << batchNumberPower;
    printf("BatchNumberPower: %llu\n", batchNumberPower);
    printf("BatchNumber: %llu\n", batchNumber);
    printf("Iterations: %llu\n", iterations);

    // Host arrays
    unsigned long long host_input0[threads];
    //unsigned long long host_input1[threads];
    unsigned long long host_result0[threads] = { 0 };
    unsigned long long* device_input0 = nullptr;
    unsigned long long* device_output0 = nullptr;
    // for 128 not 2nd GPU
    //unsigned long long* device_input1 = nullptr;
    unsigned long long* device_output1 = nullptr;
    unsigned long long host_result1[threads] = { 0 };

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

    // Iterations = 2 ^ (15(threads) + 16(endSequence = runs) + 1(odd multiplier))
    printf("GPU0: Iterations: %llu via (Threads: %llu * Batches: %d * 2 (odd mult)) ThreadsPerBlock: %d Blocks: %d\n", 
        iterations, threads, batchNumber, threadsPerBlock, blocks);
    for (int batch = 0; batch < batchNumber; batch++) {
        // prepare inputs
        for (int thread = 0; thread < threads; thread++) {
            host_input0[thread] = startSequenceNumber;
            //host_input1[thread] = 0ULL;
            startSequenceNumber += oddOffsetOptimization;
        }

        cudaMemcpy(device_input0, host_input0, size, cudaMemcpyHostToDevice);
        //cudaMemcpy(device_input1, host_input1, size, cudaMemcpyHostToDevice);
        // Launch kernel
        // kernelName<<<numBlocks, threadsPerBlock>>>(parameters...);
        collatzCUDAKernel << <blocks, threadsPerBlock >> > (/*device_input1, */device_input0, device_output1, device_output0, threads);

        // Wait for GPU to finish before accessing on host
        cudaDeviceSynchronize();

        // Copy result from device back to host
        cudaMemcpy(host_result0, device_output0, size, cudaMemcpyDeviceToHost);
        cudaMemcpy(host_result1, device_output1, size, cudaMemcpyDeviceToHost);

        // process reesults: parallelize with OpenMP
        for (int thread = 0; thread < threads; thread++) {
            if (host_result1[thread] > globalMaxValue1) {
                globalMaxValue0 = host_result0[thread];
                globalMaxValue1 = host_result1[thread];
                globalMaxStart0 = host_input0[thread];
                globalMaxStart1 = 0ULL;// host_input1[thread];

                time(&timeEnd);
                timeElapsed = difftime(timeEnd, timeStart);
                std::cout << "GPU0:Sec: " << timeElapsed << " GlobalMax: " << globalMaxStart1 << ":" << globalMaxStart0 << ": " << globalMaxValue1 
                    << ":" <<globalMaxValue0 << " last search: " << startSequenceNumber << "\n";
            } else {
                // handle only lsb gt
                if (host_result1[thread] == globalMaxValue1) {
                    if(host_result0[thread] > globalMaxValue0) {
                        globalMaxValue0 = host_result0[thread];
                        time(&timeEnd);
                        timeElapsed = difftime(timeEnd, timeStart);
                        std::cout << "GPU0:Sec: " << timeElapsed << " GlobalMax: " << globalMaxStart1 << ":" << globalMaxStart0 << ": " << globalMaxValue1
                            << ":" << globalMaxValue0 << " last search: " << startSequenceNumber << "\n";
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

    free(host_input0);
    //free(host_input1);
    free(host_result0);
    free(host_result1);
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
    unsigned int endSequencePower = 32;

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
    printf("array allocation bytes per GPU: %d * %d is %d maxSearch: %lld\n", sizeof(unsigned long long), threads, size, endSequenceNumber);
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

int main(int argc, char* argv[])
{
    int cores = (argc > 1) ? atoi(argv[1]) : 5120; // get command
    singleGPUSearch();
    //dualGPUSearch();
    return 0;
}

