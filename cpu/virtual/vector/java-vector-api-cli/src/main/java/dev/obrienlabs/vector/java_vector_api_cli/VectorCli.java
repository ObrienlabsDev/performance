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
        	for(int j=0; j<n; j+=SPECIES.length()) {
                FloatVector acc = FloatVector.zero(SPECIES);
                for (int k = 0; k < n; k++) {
                    VectorMask<Float> mask = SPECIES.indexInRange(j, n);
                    FloatVector bVec = FloatVector.fromArray(SPECIES, B[k], j, mask);
                    float valA = A[i][k];
                   
                    // fused multiply add
                    // acc = acc + (valA * bVec)
                    //acc = bVec.fma(valA, acc);
                    // Broadcast scalar valA into a vector
                    FloatVector vecA = FloatVector.broadcast(SPECIES, valA);
                    acc = bVec.fma(vecA, acc);
                }

                // accumulator
                VectorMask<Float> mask = SPECIES.indexInRange(j, n);
                acc.intoArray(C[i], j, mask);
            }
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

    /**
     * michaelobrien@mbp8 classes % java --add-modules jdk.incubator.vector -cp . dev.obrienlabs.vector.java_vector_api_cli.VectorCli
	 * 13900ks d 5.89ghz
Vector width: 256 Time: 6125 ms
	 * m3ultra
     * Vector width: 128 Time: 7979 ms
     * p1gen6
     * Vector width: 256 Time: 8135 ms
	 * Macbook Pro M4Max - 1 core
     * Vector width: 128 Time: 8671 ms
     * M2ultra
     * Vector width: 128 Time: 9199 ms

     */
}


