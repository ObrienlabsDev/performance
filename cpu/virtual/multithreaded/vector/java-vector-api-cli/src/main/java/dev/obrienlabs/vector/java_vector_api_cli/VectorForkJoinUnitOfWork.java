package dev.obrienlabs.vector.java_vector_api_cli;

import jdk.incubator.vector.*;
import java.util.concurrent.RecursiveAction;

public class VectorForkJoinUnitOfWork extends RecursiveAction {
    protected long start;
    protected long len;
    protected long uowSplit = 1024;
    protected float[][] A;
    protected float[][] B;
    protected float[][] C;
    protected int n;


    public static final long NS_TO_MS = 1_000_000;
	// No AVX-512 on intel CPUs since gen 11 (e-core introduction
	static final VectorSpecies<Float> SPECIES = FloatVector.SPECIES_PREFERRED; // .SPECIES_128;

    public VectorForkJoinUnitOfWork(long split, long start, long len, float[][] A, float[][] B, float[][] C, int n) {
        this.start = start;
        this.len = len;
        this.uowSplit = split;
        this.A = A;
        this.B = B;
        this.C = C;
        this.n = n;
    }

    protected void computeNoFork() {
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
    
    @Override
    protected void compute() {
        // base case
        //if(len <= uowSplit) {
            computeNoFork();
        //    return;
        //}
        // recursive case
        	    long split = len / 2;
	    // recursive case
	    //invokeAll(new VectorForkJoinUnitOfWork(uowSplit, start, split),
	    //          new VectorForkJoinUnitOfWork(uowSplit, start + split, len - split)
	    //);	
    }
}
