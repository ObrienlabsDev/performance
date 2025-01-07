
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
* 
*/


/* CUDA Kernel runs on GPU device streaming core */
__global__ void collatzCUDAKernel(unsigned long long* _input, unsigned long long* _output, int threads)//, unsigned long long iterations)
{
    // Calculate this thread's index
    int threadIndex = blockDim.x * blockIdx.x + threadIdx.x;

    // Check boundary (in case N is not a multiple of blockDim.x)
    int path = 0;
    unsigned long long max = _input[threadIndex];
    unsigned long long current = _input[threadIndex];

    if (threadIndex < threads)
    {
            path = 0;
            max = _input[threadIndex];
            current = _input[threadIndex];

            do {
                path += 1;
                if (current % 2 == 0) {
                    current = current >> 1;
                }
                else {
                    current = 1 + current * 3;
                    if (current > max) {
                        max = current;
                    }
                }
            } while (current > 1);
    }
    _output[threadIndex] = max;
}

void singleGPUSearch() {
    int deviceCount = 0;
    int dualDevice = 0;
    cudaGetDeviceCount(&deviceCount);
    printf("%d CUDA devices found - reallocating\n", deviceCount);
    if (deviceCount > 1) {
        dualDevice = 1;
    }

    const int dev0 = 0;
    const int dev1 = 1;

    int cores = 5120;// (argc > 1) ? atoi(argv[1]) : 5120; // get command
    // exited with code -1073741571 any higher
    // VRAM related - cannot exceed 32k threads for dual 12g RTX-3500 - check 4090
    const int threads = 32768;// 32768;// 7168 * 7;// 7168 * 4;// 32768 - (1536);// 32768 - 1536;// 7168 * 4;
    // 22sec on 7168 * 6 = 43008 55% gpu
    // 21-24 sec on 7168*7
    // 24 sec on 7168 * 8
    // 32 sec on 16384

    const int threadsPerBlock = 256;// 128;// 128; 128=50%, 256=66 on RTX-3500
    // Host arrays
    unsigned long long host_input0[threads];
    
    unsigned long long startSequence = 1L;
    unsigned long long globalMaxValue = 1L;
    unsigned long long globalMaxStart = startSequence;
    unsigned long long endSequence = 1 << 16; // 20 = 190 sec
    unsigned long long batchNumber = (endSequence - startSequence + 1) ;
    printf("%d\n", batchNumber);

    unsigned long long host_result0[threads] = { 0 };
    unsigned long long* device_input0 = nullptr;
    unsigned long long* device_output0 = nullptr;

    time_t timeStart, timeEnd;
    double timeElapsed;

    time(&timeStart);

    // Allocate memory on the GPU
    size_t size = threads * sizeof(unsigned long long);
    printf("array allocation bytes per GPU: %d * %d is %d maxSearch: %lld\n", sizeof(unsigned long long), threads, size, startSequence);
    // Number of blocks = ceiling(N / threadsPerBlock)
    int blocks = (threads + threadsPerBlock - 1) / threadsPerBlock;

    cudaSetDevice(dev0);
    cudaMalloc((void**)&device_input0, size);
    cudaMalloc((void**)&device_output0, size);

    printf("GPU0: Threads: %d ThreadsPerBlock: %d Blocks: %d\n", threads, threadsPerBlock, blocks);
    for (int batch = 0; batch < endSequence; batch++) {
        // prepare inputs
        for (int thread = 0; thread < threads; thread++) {
            host_input0[thread] = startSequence;
            startSequence += 2;
        }

        cudaSetDevice(dev0);
        cudaMemcpy(device_input0, host_input0, size, cudaMemcpyHostToDevice);
        // Launch kernel
        cudaSetDevice(dev0);
        // kernelName<<<numBlocks, threadsPerBlock>>>(parameters...);
        collatzCUDAKernel << <blocks, threadsPerBlock >> > (device_input0, device_output0, threads);

        // Wait for GPU to finish before accessing on host
        cudaSetDevice(dev0);
        cudaDeviceSynchronize();

        // Copy result from device back to host
        cudaMemcpy(host_result0, device_output0, size, cudaMemcpyDeviceToHost);

        // process reesults: parallelize with OpenMP
        for (int thread = 0; thread < threads; thread++)
        {
            if (host_result0[thread] > globalMaxValue) {
                globalMaxValue = host_result0[thread];
                globalMaxStart = host_input0[thread];
                time(&timeEnd);
                timeElapsed = difftime(timeEnd, timeStart);
                std::cout << "GPU0:Sec: " << timeElapsed << " GlobalMax: " << globalMaxStart << ": " << globalMaxValue << " last search: " << startSequence << "\n";
            }
        }
    }

    // Print the result for the last run
    std::cout << "collatz:\n";
    int i = 0;
    for (int i = 0; i < 20/*threads*/; i++)
    {
        std::cout << "GPU0: " << i << ": " << host_input0[i] << " = " << host_result0[i] << "\n";
    }

    time(&timeEnd);
    timeElapsed = difftime(timeEnd, timeStart);

    printf("duration: %.f\n", timeElapsed);
    std::cout << "Sec: " << timeElapsed << " GlobalMax: " << globalMaxStart << " : " << globalMaxValue << " last search : " << startSequence << "\n";

    // Free GPU memory
    cudaSetDevice(dev0);
    cudaFree(device_input0);
    cudaFree(device_output0);

    free(host_input0);
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

    const int dev0 = 0;
    const int dev1 = 1;

    int cores = 5120;// (argc > 1) ? atoi(argv[1]) : 5120; // get command
    // exited with code -1073741571 any higher
    // VRAM related - cannot exceed 32k threads for dual 12g RTX-3500 - check 4090
    const int threads = 16384;// 32768;// 7168 * 7;// 7168 * 4;// 32768 - (1536);// 32768 - 1536;// 7168 * 4;
    // 22sec on 7168 * 6 = 43008 55% gpu
    // 21-24 sec on 7168*7
    // 24 sec on 7168 * 8
    // 32 sec on 16384

    const int threadsPerBlock = 256;// 128; 128=50%, 256=66 on RTX-3500
    // Host arrays
    unsigned long long host_input0[threads];
    unsigned long long host_input1[threads];

    unsigned long long startSequence = 1L;
    unsigned long long globalMaxValue = 1L;
    unsigned long long globalMaxStart = startSequence;
    unsigned long long endSequence = 1 << 16; // 20 = 190 sec

    unsigned long long host_result0[threads] = { 0 };
    unsigned long long host_result1[threads] = { 0 };

    // Device pointers
    unsigned long long* device_input0 = nullptr;
    unsigned long long* device_output0 = nullptr;
    unsigned long long* device_input1 = nullptr;
    unsigned long long* device_output1 = nullptr;

    time_t timeStart, timeEnd;
    double timeElapsed;

    time(&timeStart);

    // Allocate memory on the GPU
    size_t size = threads * sizeof(unsigned long long);
    printf("array allocation bytes per GPU: %d * %d is %d maxSearch: %lld\n", sizeof(unsigned long long), threads, size, startSequence);
    // Number of blocks = ceiling(N / threadsPerBlock)
    int blocks = (threads + threadsPerBlock - 1) / threadsPerBlock;

    cudaSetDevice(dev0);
    cudaMalloc((void**)&device_input0, size);
    cudaMalloc((void**)&device_output0, size);

    if (dualDevice > 0) {
        cudaSetDevice(dev1);
        cudaMalloc((void**)&device_input1, size);
        cudaMalloc((void**)&device_output1, size);
    }

    // prep for iteration
    int x;
    // 32k - 1.5k
    // GPU0: Iterations: 8388608 Threads: 31232 ThreadsPerBlock: 64 Blocks: 488
    printf("GPU0: Threads: %d ThreadsPerBlock: %d Blocks: %d\n", threads, threadsPerBlock, blocks);
    if (dualDevice > 0) {
        printf("GPU1: Threads: %d ThreadsPerBlock: %d Blocks: %d\n", threads, threadsPerBlock, blocks);
    }

    for (x = 0; x < endSequence; x++) {
        for (int q = 0; q < threads; q++) {
            host_input0[q] = startSequence;
            if (dualDevice > 0) {
                startSequence += 2;
                host_input1[q] = startSequence;
            }
            startSequence += 2;
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
        collatzCUDAKernel << <blocks, threadsPerBlock >> > (device_input0, device_output0, threads);

        if (dualDevice > 0) {
            cudaSetDevice(dev1);
            collatzCUDAKernel << <blocks, threadsPerBlock >> > (device_input1, device_output1, threads);
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
        for (int i = 0; i < threads; i++)
        {
            if (host_result0[i] > globalMaxValue) {
                globalMaxValue = host_result0[i];
                globalMaxStart = host_input0[i];
                time(&timeEnd);
                timeElapsed = difftime(timeEnd, timeStart);
                std::cout << "GPU0:Sec: " << timeElapsed << " GlobalMax: " << globalMaxStart << ": " << globalMaxValue << " last search: " << startSequence << "\n";
            }
            if (dualDevice > 0) {
                if (host_result1[i] > globalMaxValue) {
                    globalMaxValue = host_result1[i];
                    globalMaxStart = host_input1[i];
                    time(&timeEnd);
                    timeElapsed = difftime(timeEnd, timeStart);
                    std::cout << "GPU1:Sec: " << timeElapsed << " GlobalMax: " << globalMaxStart << ": " << globalMaxValue << " last search: " << startSequence << "\n";
                }
            }
        }
    }

    // Print the result
    std::cout << "collatz:\n";
    int i = 0;
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
    std::cout << "Sec: " << timeElapsed << " GlobalMax: " << globalMaxStart << " : " << globalMaxValue << " last search : " << startSequence << "\n";

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

/* Host progrem */
int main(int argc, char* argv[])
{
    int cores = (argc > 1) ? atoi(argv[1]) : 5120; // get command
    singleGPUSearch();
    //dualGPUSearch();
    return 0;
}

