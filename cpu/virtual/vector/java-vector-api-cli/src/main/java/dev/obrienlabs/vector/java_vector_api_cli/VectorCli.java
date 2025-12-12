package dev.obrienlabs.vector.java_vector_api_cli;

import jdk.incubator.vector.*;

/**
 * https://github.com/ObrienlabsDev/performance/issues/42
 */
public class VectorCli {
	
	static final VectorSpecies<Float> SPECIES = FloatVector.SPECIES_PREFERRED;
	
    public static void main( String[] args) {
        VectorCli vectorCli = new VectorCli();
        int N = 1024; 
        float[][] A = new float[N][N];
        float[][] B = new float[N][N];
        float[][] C = new float[N][N];
    }
}
