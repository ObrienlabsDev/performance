package dev.obrienlabs.performance.nbi;

import dev.obrienlabs.performance.nbi.math.ULong128;
import dev.obrienlabs.performance.nbi.math.ULong128Impl;

// I know - use JUnit 5
class CollatzTest {

	
	void test128bitAdd() {
		ULong128 a = new ULong128Impl(2L, 3L);
		ULong128 b = new ULong128Impl(1L, 1L);
		ULong128 expected = new ULong128Impl(3L, 4L);
		
		/**
		 * Adding 2 longs 
		 * we add the low bytes, detect the carry, add the high bytes and add the carry
		 * 
		 */
		ULong128 c = a.add(b);
		assert c.getLong1() == expected.getLong1();
		assert c.getLong0() == expected.getLong0();
		
	}
	
	//@Test
	void contextLoads() {
	}
	
	public static void main(String[] args) {
		CollatzTest test = new CollatzTest();
		test.test128bitAdd();
	}

}
