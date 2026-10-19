package com.jackwallner.streaks

import java.security.MessageDigest

import org.junit.Assert.*
import org.junit.Test

import com.jackwallner.streaks.model.ReviewAccess

class ReviewAccessTest {
    private val fixture = "local-review-fixture"
    private val digest = MessageDigest.getInstance("SHA-256").digest(fixture.toByteArray()).joinToString("") { "%02x".format(it) }

    @Test fun unconfiguredAccessCannotUnlock() {
        assertFalse(ReviewAccess(MemoryValues(), "").activate(fixture))
        assertFalse(ReviewAccess(MemoryValues(), "invalid").isGranted)
    }

    @Test fun wrongOrBlankCodeDoesNotGrantAccess() {
        val access = ReviewAccess(MemoryValues(), digest)
        assertFalse(access.activate("wrong"))
        assertFalse(access.activate(" "))
        assertFalse(access.isGranted)
    }

    @Test fun validCodePersistsOnlyDigestAcrossRecreation() {
        val values = MemoryValues()
        assertTrue(ReviewAccess(values, digest).activate(" $fixture "))
        assertTrue(ReviewAccess(values, digest).isGranted)
        assertEquals(mapOf("reviewAccessDigest" to digest), values.entries())
    }

    @Test fun rotatingDigestInvalidatesExistingAccess() {
        val values = MemoryValues()
        assertTrue(ReviewAccess(values, digest).activate(fixture))
        assertFalse(ReviewAccess(values, "0".repeat(64)).isGranted)
    }
}
