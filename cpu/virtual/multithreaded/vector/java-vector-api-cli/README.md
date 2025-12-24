#
```
single core baseline
michaelobrien@ultra3 java-vector-api-cli % java -Xmx90000m --add-modules jdk.incubator.vector -cp target/classes dev.obrienlabs.vector.java_vector_api_cli.VectorForkJoinPool
WARNING: Using incubator modules: jdk.incubator.vector
Vector size: 16384
matrix init time: 1026 ms
Vector size: 2048 width: 128 Time: 12410 ms 

first split - 8 p cores
michaelobrien@ultra3 java-vector-api-cli % java -Xmx90000m --add-modules jdk.incubator.vector -cp target/classes dev.obrienlabs.vector.java_vector_api_cli.VectorForkJoinPool
WARNING: Using incubator modules: jdk.incubator.vector
Vector size: 16384
matrix init time: 1089 ms
Vector size: 2048 width: 128 Time: 14711 ms 

```
