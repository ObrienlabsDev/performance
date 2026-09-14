#!/bin/sh

LAST1=37
echo $LAST1
#for i in {6..37}
for i in $(seq 8 $LAST1);
do
  echo "running 0 $LAST1 $i"
  java -cp target/performance-nbi-0.0.1-SNAPSHOT.jar dev.obrienlabs.performance.nbi.Collatz128bit 0 $LAST1 $i
done
