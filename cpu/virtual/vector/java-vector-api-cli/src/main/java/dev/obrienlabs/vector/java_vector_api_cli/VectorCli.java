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
	As you can see there is some random noise around 25-50% affecting performance - which performance core is active or busy
     * michaelobrien@mbp8 classes % java --add-modules jdk.incubator.vector -cp . dev.obrienlabs.vector.java_vector_api_cli.VectorCli
	 * custom 13900KS d 5.89ghz
     *   Vector width: 256 Time: 6125 ms
	 * custom 13900K b 4090 dual 5.6ghz (no HT, no E cores)
	 *   Vector width: 256 Time: 6998 ms
	 * Mini09 M4 only
	 *   Vector width: 128 Time: 7738 ms
	 * MacStudio M3 Ultra
     *   Vector width: 128 Time: 7979 ms
     * Lenovo p1gen6 13800H
     *   Vector width: 256 Time: 8135 ms
	 * Mini10 M4 Pro
	 *   Vector width: 128 Time: 8489 ms
	 * Macbook Pro M4 Max - 1 core
     *   Vector width: 128 Time: 8671 ms

	 * custom 14900K A6000
	 *   Vector width: 256 Time: 9130 ms
     * MacStudio M2 Ultra
     *   Vector width: 128 Time: 9199 ms
     * Macbook Pro M1 Max macbook pro
     *   Vector width: 128 Time: 9721 ms
	 * NVIDIA / PNY DGX Spark with Grace Blackwel GB10 - a bit slower than anticipated - will check turning off the e-cores
     *   Vector width: 128 Time: 21590 ms


	 13900k with dual 4090 (e cores enabled, ht on) - depending on core speed 4.6 to 5.6ghz

	 michael@13900b MINGW64 /c/wse_github/obrienlabsdev/performance/cpu/virtual/vector/java-vector-api-cli/target/classes (main)
$ java --add-modules jdk.incubator.vector -cp . dev.obrienlabs.vector.java_vector_api_cli.VectorCli
WARNING: Using incubator modules: jdk.incubator.vector
Vector width: 256 Time: 13657 ms
(base)
michael@13900b MINGW64 /c/wse_github/obrienlabsdev/performance/cpu/virtual/vector/java-vector-api-cli/target/classes (main)
$ java --add-modules jdk.incubator.vector -cp . dev.obrienlabs.vector.java_vector_api_cli.VectorCli
WARNING: Using incubator modules: jdk.incubator.vector
Vector width: 256 Time: 14588 ms

(base)
michael@13900b MINGW64 /c/wse_github/obrienlabsdev/performance/cpu/virtual/vector/java-vector-api-cli/target/classes (main)
$ java --add-modules jdk.incubator.vector -cp . dev.obrienlabs.vector.java_vector_api_cli.VectorCli
WARNING: Using incubator modules: jdk.incubator.vector
Vector width: 256 Time: 8569 ms
(base)
michael@13900b MINGW64 /c/wse_github/obrienlabsdev/performance/cpu/virtual/vector/java-vector-api-cli/target/classes (main)
$ java --add-modules jdk.incubator.vector -cp . dev.obrienlabs.vector.java_vector_api_cli.VectorCli
WARNING: Using incubator modules: jdk.incubator.vector
Vector width: 256 Time: 6998 ms

after turning off 8 e cores and e-core ht - remaining 8 p cores only

michael@13900b MINGW64 /c/wse_github/obrienlabsdev/performance/cpu/virtual/vector/java-vector-api-cli/target/classes (main)
$ java --add-modules jdk.incubator.vector -cp . dev.obrienlabs.vector.java_vector_api_cli.VectorCli
WARNING: Using incubator modules: jdk.incubator.vector
Vector width: 256 Time: 7959 ms
(base)
michael@13900b MINGW64 /c/wse_github/obrienlabsdev/performance/cpu/virtual/vector/java-vector-api-cli/target/classes (main)
$ java --add-modules jdk.incubator.vector -cp . dev.obrienlabs.vector.java_vector_api_cli.VectorCli
WARNING: Using incubator modules: jdk.incubator.vector
Vector width: 256 Time: 8183 ms
(base)
michael@13900b MINGW64 /c/wse_github/obrienlabsdev/performance/cpu/virtual/vector/java-vector-api-cli/target/classes (main)
$ java --add-modules jdk.incubator.vector -cp . dev.obrienlabs.vector.java_vector_api_cli.VectorCli
WARNING: Using incubator modules: jdk.incubator.vector
Vector width: 256 Time: 7613 ms
(base)
michael@13900b MINGW64 /c/wse_github/obrienlabsdev/performance/cpu/virtual/vector/java-vector-api-cli/target/classes (main)
$ java --add-modules jdk.incubator.vector -cp . dev.obrienlabs.vector.java_vector_api_cli.VectorCli
WARNING: Using incubator modules: jdk.incubator.vector
Vector width: 256 Time: 7782 ms


	 * NVIDIA / PNY DGX Spark with Grace Blackwel GB10 - a bit slower than anticipated - will check turning off the e-cores
michael@spark-7d19:~/wse_github/ObrienlabsDev/performance/cpu/virtual/vector/java-vector-api-cli/target/classes$ java --add-modules=jdk.incubator.vector -cp . dev.obrienlabs.vector.java_vector_api_cli.VectorCli
WARNING: Using incubator modules: jdk.incubator.vector
Vector width: 128 Time: 21590 ms

     */
}


