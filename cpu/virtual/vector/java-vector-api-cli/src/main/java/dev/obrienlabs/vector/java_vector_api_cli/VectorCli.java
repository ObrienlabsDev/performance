package dev.obrienlabs.vector.java_vector_api_cli;

import jdk.incubator.vector.*;

/**
 * https://github.com/ObrienlabsDev/performance/issues/42
 */
public class VectorCli {
	
	// No AVX-512 on intel CPUs since gen 11 (e-core introduction
	static final VectorSpecies<Float> SPECIES = FloatVector.SPECIES_PREFERRED; // .SPECIES_128;

	/**
	 * nxn matrices
	 */
    public static void multiply(float[][] A, float[][] B, float[][] C, int n) {   
        for(int i=0; i<n; i++) {
        }
    }
	
    public static void main( String[] args) {
        VectorCli vectorCli = new VectorCli();
        int N = 2048;//1024; 
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

        long start = System.nanoTime();
        multiply(A, B, C, N);
        long duration = 1 + System.nanoTime() - start; // divide/zero/error

        System.out.printf("Vector width: %d Time: %d ms%n", SPECIES.vectorBitSize(), duration / 1_000_000);
    }
}
