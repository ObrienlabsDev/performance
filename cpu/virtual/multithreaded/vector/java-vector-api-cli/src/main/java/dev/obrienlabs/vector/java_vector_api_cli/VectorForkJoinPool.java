package dev.obrienlabs.vector.java_vector_api_cli;

import java.util.concurrent.ForkJoinPool;
import jdk.incubator.vector.*;


/**
 * https://github.com/ObrienlabsDev/performance/issues/42
 */

public class VectorForkJoinPool {// extends ForkJoinPool {
    protected ForkJoinPool mapReducePool;

    public static final long NS_TO_MS = 1_000_000;
    // No AVX-512 on intel CPUs since gen 11 (e-core introduction
	static final VectorSpecies<Float> SPECIES = FloatVector.SPECIES_PREFERRED; // .SPECIES_128;

    public void compute() {
        int N = 32768;//65536;
        System.out.printf("Vector size: %d\n", N); 
        long start = System.nanoTime();
        float[][] A = new float[N][N];
        float[][] B = new float[N][N];
        float[][] C = new float[N][N];
        
        // fake values
        for(int i=0; i<N; i++) {
            for(int j=0; j<N; j++) {
                A[i][j] = 1.0f;
                B[i][j] = 2.0f;
            }
        }
        long duration = 1 + System.nanoTime() - start; 
        System.out.printf("matrix init time: %d ms\n", duration / NS_TO_MS);
        // size = 1 << 11 = split = single threaded
        int size = 1 << 12;//2;
        int split = 1 << 10;
        //for (int step=1; step<16; step++) {
            start = System.nanoTime();
            //multiplyParallel(A, B, C, size);//N);
            VectorForkJoinUnitOfWork uow = new VectorForkJoinUnitOfWork(split, 0, size,
                A, B, C, size);
            mapReducePool = new ForkJoinPool();
            mapReducePool.invoke(uow);
            duration = 1 + System.nanoTime() - start; // divide/zero/error
            System.out.printf("Vector size: %d width: %d Time: %d ms %n\n", size, SPECIES.vectorBitSize(), duration / NS_TO_MS);
            size*=2;
        //}
    }

    public static void main( String[] args) {
        VectorForkJoinPool pool = new VectorForkJoinPool();
        pool.compute();
    }
}
    

