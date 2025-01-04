package dev.obrienlabs.performance.nbi;

import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

import dev.obrienlabs.performance.nbi.math.ULong128;
import dev.obrienlabs.performance.nbi.math.ULong128Impl;

// I know - use JUnit 5
class CollatzTest {

	@Test
	void test128bitAddWithoutOverflow() {
		ULong128 a = new ULong128Impl(2L, 3L);
		ULong128 b = new ULong128Impl(1L, 1L);
		ULong128 expected = new ULong128Impl(3L, 4L);
		ULong128 c = a.add(b);
		assert c.getLong1() == expected.getLong1();
		assertTrue(c.getLong0() == expected.getLong0());
	}

	@Test
	void test128bitAddWithMaxOverflow() {
		ULong128 a = new ULong128Impl(1L, Long.MAX_VALUE + Long.MAX_VALUE + 1);
		ULong128 b = new ULong128Impl(0L, 1L);
		ULong128 expected = new ULong128Impl(2L, 0L);
		ULong128 c = a.add(b);
		assertTrue(c.getLong1() == expected.getLong1());
		assertTrue(c.getLong0() == expected.getLong0());
	}

	@Test
	void test128bitAddWithMediumOverflow() {
		ULong128 a = new ULong128Impl(1L, Long.MAX_VALUE + Long.MAX_VALUE + 1);
		ULong128 b = new ULong128Impl(0L, 65536L);
		ULong128 expected = new ULong128Impl(2L, 65535L);
		ULong128 c = a.add(b);
		assertTrue(c.getLong1() == expected.getLong1());
		assertTrue(c.getLong0() == expected.getLong0());
	}

	@Test
	// variant
	void test128bitAddAtBit31NoOverflow() {
		ULong128 a = new ULong128Impl(1L, Long.MAX_VALUE); // 2^31-1 = 9223372036854775807
		ULong128 b = new ULong128Impl(0L, 65536L);
		ULong128 expected = new ULong128Impl(1L, Long.MAX_VALUE + 65536L);
		ULong128 c = a.add(b);
		assertTrue(c.getLong1() == expected.getLong1());
		assertTrue(c.getLong0() == expected.getLong0());
	}
}
