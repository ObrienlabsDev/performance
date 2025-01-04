package dev.obrienlabs.performance.nbi.math;

import java.util.Objects;

/**
 * Algorithm
 * Math.multiplyHigh - check it
 */
public class ULong128Impl implements ULong128 {

	
	private long long0;
	private long long1;
	
	public ULong128Impl() {
		this(0L, 0L);
	}

	public ULong128Impl(long long0) {
		this(0L, long0);
	}
	
	public ULong128Impl(long long1, long long0) {
		//super();
		this.long0 = long0;
		this.long1 = long1;
	}
	
	@Override
	public boolean isEven() {
		// testBit(0)
		return long0 % 2 == 0;
	}

	@Override
	public boolean isGreaterThan(ULong128 ulong128) {
		return false;
	}
	
	@Override
	// we add the low bytes, detect the carry, add the high bytes and add the carry
	public ULong128 add(ULong128 ulong128) {;
		long temp0 = this.getLong0() + ulong128.getLong0();
		// a smaller result means we experienced overflow
		long carry0 = Long.compareUnsigned(temp0, this.getLong0()) < 0 ? 1L : 0L;
		long temp1 = this.getLong1() + ulong128.getLong1() + carry0;
		return new ULong128Impl(temp1, temp0);
	}
	
	@Override
	public ULong128 shiftLeft(int positions) {
		ULong128 result = this;
		return result;
	}
	
	@Override
	public ULong128 shiftRight(int positions) {
		ULong128 result = this;
		return result;
	}
	
	@Override
	public long getLong0() {
		return long0;
	}
	@Override
	public void setLong0(long long0) {
		this.long0 = long0;
	}
	@Override
	public long getLong1() {
		return long1;
	}
	@Override
	public void setLong1(long long1) {
		this.long1 = long1;
	}
	@Override
	public String toString() {
		return new StringBuffer().append(long1).append(":").append(long0).toString();
	}
	@Override
	public int hashCode() {
		return Objects.hash(long0, long1);
	}
	@Override
	public boolean equals(Object obj) {
		if (this == obj)
			return true;
		if (obj == null)
			return false;
		if (getClass() != obj.getClass())
			return false;
		ULong128Impl other = (ULong128Impl) obj;
		return long0 == other.long0 && long1 == other.long1;
	}

}
