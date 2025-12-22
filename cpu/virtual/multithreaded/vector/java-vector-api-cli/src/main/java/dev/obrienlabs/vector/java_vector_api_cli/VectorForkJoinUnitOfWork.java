package dev.obrienlabs.vector.java_vector_api_cli;

import jdk.incubator.vector.*;
import java.util.concurrent.RecursiveAction;

/**
 * https://github.com/ObrienlabsDev/performance/issues/42
 */
public class VectorForkJoinUnitOfWork extends RecursiveAction {
    protected long start;
    protected long len;
    protected long uowSplit;
    protected float[][] A;
    protected float[][] B;
    protected float[][] C;
    protected int vectorSize;
 
    public static final long NS_TO_MS = 1_000_000;
	// No AVX-512 on intel CPUs since gen 11 (e-core introduction
	static final VectorSpecies<Float> SPECIES = FloatVector.SPECIES_PREFERRED; // .SPECIES_128;

    public VectorForkJoinUnitOfWork(long split, long start, long len, 
        float[][] A, float[][] B, float[][] C, int vectorSize) {
        this.start = start;
        this.len = len;
        this.uowSplit = split;
        this.A = A;
        this.B = B;
        this.C = C;
        this.vectorSize = vectorSize;
    }

    protected void computeNoFork() {
       for(int i=0; i<vectorSize; i++) {
        	for(int j=0; j<vectorSize; j+=SPECIES.length()) {
                FloatVector acc = FloatVector.zero(SPECIES);
                for (int k = 0; k < vectorSize; k++) {
                    VectorMask<Float> mask = SPECIES.indexInRange(j, vectorSize);
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
                VectorMask<Float> mask = SPECIES.indexInRange(j, vectorSize);
                acc.intoArray(C[i], j, mask);
            }
        }
    }
    
    @Override
    protected void compute() {
        // base case
        if(len <= uowSplit) {
            computeNoFork();
            return;
        }
        // recursive case
        long split = len / 2;
	    invokeAll(new VectorForkJoinUnitOfWork(uowSplit, start, split, A, B, C, vectorSize),
	              new VectorForkJoinUnitOfWork(uowSplit, start + split, len - split, A, B, C, vectorSize)
	    );	
    }
}
