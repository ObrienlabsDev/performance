/*
See LICENSE folder for this sample’s licensing information.
Apple Inc.

Abstract:
An Objective C class to manage all of the Metal objects this app creates.

michaelobrien 20250222 adjustments
3G ram for float 6 g double, 96% GPU, 2% CPU - M4Max 16/40
*/

#import "MetalAdder.h"
#include <time.h>

// The number of floats in each array, and the size of the arrays in bytes.
const unsigned long arrayLength = 1 << 29	;//24; after 27 m4max 40 gpu is 1.6x slower than m2ultra 60 gpu
const unsigned long iterations = 1 << 13; // 1 second overhead
const unsigned long bufferSize = arrayLength * sizeof(double);

@implementation MetalAdder {
    id<MTLDevice> _mDevice;

    // The compute pipeline generated from the compute kernel in the .metal shader file.
    id<MTLComputePipelineState> _mAddFunctionPSO;

    // The command queue used to pass commands to the device.
    id<MTLCommandQueue> _mCommandQueue;

    // Buffers to hold data.
    id<MTLBuffer> _mBufferA;
    id<MTLBuffer> _mBufferB;
    id<MTLBuffer> _mBufferResult;
}

- (instancetype) initWithDevice: (id<MTLDevice>) device {
    self = [super init];
    if (self) {
        _mDevice = device;
        NSError* error = nil;
        // Load the shader files with a .metal file extension in the project

        id<MTLLibrary> defaultLibrary = [_mDevice newDefaultLibrary];
        if (defaultLibrary == nil) {
            NSLog(@"Failed to find the default library.");
            return nil;
        }

        id<MTLFunction> addFunction = [defaultLibrary newFunctionWithName:@"add_arrays"];
        if (addFunction == nil) {
            NSLog(@"Failed to find the adder function.");
            return nil;
        }

        // Create a compute pipeline state object.
        _mAddFunctionPSO = [_mDevice newComputePipelineStateWithFunction: addFunction error:&error];
        if (_mAddFunctionPSO == nil) {
            //  If the Metal API validation is enabled, you can find out more information about what
            //  went wrong.  (Metal API validation is enabled by default when a debug build is run
            //  from Xcode)
            NSLog(@"Failed to created pipeline state object, error %@.", error);
            return nil;
        }

        _mCommandQueue = [_mDevice newCommandQueue];
        if (_mCommandQueue == nil) {
            NSLog(@"Failed to find the command queue.");
            return nil;
        }
    }
    return self;
}

- (void) prepareData {
    // Allocate three buffers to hold our initial data and the result.
    printf("allocating ram\n");
    _mBufferA = [_mDevice newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];
    _mBufferB = [_mDevice newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];
    _mBufferResult = [_mDevice newBufferWithLength:bufferSize options:MTLResourceStorageModeShared];
    [self generateRandomData:_mBufferA];
    [self generateRandomData:_mBufferB];
    printf("ram allocated\n");
}

- (void) sendComputeCommand {
    time_t timeStart, timeEnd;
    double timeElapsed;
    time(&timeStart);
    
    printf("Iterations: %lu\n", iterations);
    
    // Create a command buffer to hold commands
    for (unsigned long iter=0; iter<iterations; iter++) {
    id<MTLCommandBuffer> commandBuffer = [_mCommandQueue commandBuffer];
    assert(commandBuffer != nil);
    
    // Start a compute pass.
    //printf("Starting compute pass\n");
    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
    assert(computeEncoder != nil);

    [self encodeAddCommand:computeEncoder];
    
    // End the compute pass.
    //printf("endEncoding\n");
    [computeEncoder endEncoding];

    // Execute the command.
    //printf("commit\n");
    [commandBuffer commit];
    
    // Normally, you want to do other work in your app while the GPU is running,
    // but in this example, the code simply blocks until the calculation is complete.
    //printf("start waitUntilCompleted\n");
    [commandBuffer waitUntilCompleted];
    //printf("end waitUntilCompleted\n");
    }
    time(&timeEnd);
    timeElapsed = difftime(timeEnd, timeStart);
    printf("Time: %g seconds\n", timeElapsed);
    //[self verifyResults];
}

- (void)encodeAddCommand:(id<MTLComputeCommandEncoder>)computeEncoder {
    // Encode the pipeline state object and its parameters.
    [computeEncoder setComputePipelineState:_mAddFunctionPSO];
    [computeEncoder setBuffer:_mBufferA offset:0 atIndex:0];
    [computeEncoder setBuffer:_mBufferB offset:0 atIndex:1];
    [computeEncoder setBuffer:_mBufferResult offset:0 atIndex:2];

    MTLSize gridSize = MTLSizeMake(arrayLength, 1, 1);

    // Calculate a threadgroup size.
    NSUInteger threadGroupSize = _mAddFunctionPSO.maxTotalThreadsPerThreadgroup;
    if (threadGroupSize > arrayLength) {
        threadGroupSize = arrayLength;
    }
    MTLSize threadgroupSize = MTLSizeMake(threadGroupSize, 1, 1);

    // Encode the compute command.
    [computeEncoder dispatchThreads:gridSize
              threadsPerThreadgroup:threadgroupSize];
}

- (void) generateRandomData: (id<MTLBuffer>) buffer {
    double* dataPtr = buffer.contents;
    for (unsigned long index = 0; index < arrayLength; index++) {
        dataPtr[index] = (double)rand()/(double)(RAND_MAX);
    }
}

- (void) verifyResults {
    double* a = _mBufferA.contents;
    double* b = _mBufferB.contents;
    double* result = _mBufferResult.contents;
    printf("Verifying results...\n");
    for (unsigned long index = 0; index < arrayLength; index++) {
        if (result[index] != (a[index] + b[index])) {
            printf("Compute ERROR: index=%lu result=%g vs %g=a+b\n",
                   index, result[index], a[index] + b[index]);
            assert(result[index] == (a[index] + b[index]));
        //} else {
        //    printf("Compute: index=%lu result=%g vs %g=a+b\n",
        //           index, result[index], a[index] + b[index]);
        }
    }
    printf("Compute results as expected: result[0]=%g vs %g=a+b\n", result[0], a[0] + b[0]);
}
@end
