package dev.obrienlabs.performance.nbi.math;

public interface ULong128 {
	
	//static ULong128 ONE {
	//	return new ULong128Impl();
	//}

	boolean isEven();
	
	boolean isGreaterThan(ULong128 ulong128);
	
	ULong128 add(ULong128 ulong128);

	ULong128 shiftLeft(int positions);

	ULong128 shiftRight(int positions);

	long getLong0();

	void setLong0(long long0);

	long getLong1();

	void setLong1(long long1);

}