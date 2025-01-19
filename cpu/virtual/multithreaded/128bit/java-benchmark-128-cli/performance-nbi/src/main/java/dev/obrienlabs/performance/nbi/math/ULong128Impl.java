package dev.obrienlabs.performance.nbi.math;

import java.math.BigInteger;
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
		return long0 % 2 == 0;
	}

	@Override
	public boolean isGreaterThan(ULong128 ulong128) {
		// check high (fast exit), then low
		int topCompare = Long.compareUnsigned(this.long1, ulong128.getLong1());
		
		if(topCompare < 0) {
			return false;
		} else {
			if(topCompare > 0) {
				return true;
			} else {
				int lowCompare = Long.compareUnsigned(this.long0, ulong128.getLong0());
				if(lowCompare < 0) {
					return false;
				} else {
					if(lowCompare > 0) {
						return true;
					} else {
						return false;
					}
				}
			}
		}
	}
	
	@Override
	// we add the low bytes, detect the carry, add the high bytes and add the carry
	public ULong128 add(ULong128 ulong128) {
		long temp0 = this.long0 + ulong128.getLong0();
		// a smaller result means we experienced overflow
		long carry0 = Long.compareUnsigned(temp0, this.getLong0()) < 0 ? 1L : 0L;
		long temp1 = this.long1 + ulong128.getLong1() + carry0;
		return new ULong128Impl(temp1, temp0);
		//this.long1 = this.long1 + ulong128.getLong1() + carry0;
		//this.long0 = temp0;
		//return this;
	}
	
	@Override
	// use >>> triple shift to fill 0's on the right
	public ULong128 shiftLeft(int positions) {
		// we only shift one digit
		return this.add(this);
	}
	
	@Override
	// use >>> triple shift to fill 0's on the right
	public ULong128 shiftRight(int positions) {
		// multiply by 2 until we have the last LSB shifted to MSBit left position
		long highShiftedLeft63BitsInPrepOfAddToLow = this.long1 << 63;//(64 - positions);
		long temp0 = (this.long0 >>> 1) + highShiftedLeft63BitsInPrepOfAddToLow ;
		long temp1 = this.long1 >>> 1;
		return new ULong128Impl(temp1, temp0);
		//this.long0 = (this.long0 >>> 1) + highShiftedLeft63BitsInPrepOfAddToLow ;
		//this.long1 = this.long1 >>> 1;	
		//return this;
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
	public String toUnsigned128String() {
		BigInteger result = BigInteger.valueOf(0L);
		if(long1 > 0) {
			result = result.add(BigInteger.valueOf(Long.MAX_VALUE));
			result = result.add(BigInteger.valueOf(1L)); // add 1 to above 2^63 - 1  - will add 2 after shift
			result = result.shiftLeft(1);
			result = result.multiply(BigInteger.valueOf(long1));
		} else {
			if(long1 < 0) { // handle 127th bit
				result = result.add(BigInteger.valueOf(Long.MAX_VALUE));
				result = result.add(BigInteger.valueOf(1L));
				result = result.shiftLeft(1);
				result = result.multiply(BigInteger.valueOf(long1));
				result = result.setBit(127); // test
			}
		}

		if(long0 < 0) { // handle 63 bit
			result = result.add(BigInteger.valueOf(long0));//.negate());
			result = result.add(BigInteger.valueOf(Long.MAX_VALUE));
			result = result.add(BigInteger.valueOf(1L)); // add 1 to above 2^63 - 1
			result = result.add(BigInteger.valueOf(Long.MAX_VALUE));
			result = result.add(BigInteger.valueOf(1L)); // add 1 to above 2^63 - 1
		} else {
			result = result.add(BigInteger.valueOf(long0));
		}
		return result.toString();
	}
	
	@Override
	public String toString() {
		return new StringBuffer().append(long1).append(":").append(Long.toUnsignedString(long0)).toString();
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
