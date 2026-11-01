package dev.marcos.avdstudio.core.sdk

import dev.marcos.avdstudio.core.touch
import okio.fakefilesystem.FakeFileSystem
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.time.Duration.Companion.seconds
import kotlin.time.Instant

class SdkDownloadMonitorTest {
    private val clock = MutableClock(Instant.fromEpochSeconds(1_000))
    private val fs = FakeFileSystem(clock = clock)
    private val sdk = "/sdk"

    private class MutableClock(
        var now: Instant,
    ) : kotlin.time.Clock {
        override fun now(): Instant = now
    }

    private fun write(
        path: String,
        bytes: Int,
    ) = fs.touch(path, "x".repeat(bytes))

    private fun bytes(since: Long) = SdkDownloadMonitor(fs).downloadedBytes(sdk, since)

    @Test
    fun nothingDownloadedMeansZeroEvenWithoutTheFolders() {
        assertEquals(0L, bytes(0))
    }

    @Test
    fun countsTheArchiveSdkmanagerIsWritingNow() {
        write("$sdk/.sdk/arch/6ae7.part", 1_200)

        assertEquals(1_200L, bytes(0))
    }

    @Test
    fun theCountGrowsAsTheFileGrows() {
        write("$sdk/.sdk/arch/6ae7.part", 500)
        val first = bytes(0)
        clock.now += 1.seconds
        write("$sdk/.sdk/arch/6ae7.part", 4_000)

        assertEquals(500L, first)
        assertEquals(4_000L, bytes(0))
    }

    @Test
    fun anArchiveThatFinishedStillCountsOnceRenamed() {
        write("$sdk/.sdk/arch/6ae7", 9_000)

        assertEquals(9_000L, bytes(0))
    }

    @Test
    fun severalImagesAddUp() {
        write("$sdk/.sdk/arch/a", 3_000)
        write("$sdk/.sdk/arch/b.part", 1_000)

        assertEquals(4_000L, bytes(0))
    }

    @Test
    fun anArchiveFromEarlierIsNotThisDownload() {
        write("$sdk/.sdk/arch/old", 7_000)
        clock.now += 100.seconds
        val started = clock.now.toEpochMilliseconds()
        write("$sdk/.sdk/arch/new.part", 300)

        assertEquals(300L, bytes(started), "the reused archive was not downloaded again")
    }

    @Test
    fun theOlderSdkmanagerFoldersAreCountedToo() {
        write("$sdk/.downloadIntermediates/system.zip", 2_000)
        write("$sdk/.temp/PackageOperation01/part.zip", 500)

        assertEquals(2_500L, bytes(0))
    }

    @Test
    fun unzippedFilesAreNotDownloads() {
        write("$sdk/.sdk/unzips/6ae7/system.img", 50_000)
        write("$sdk/platform-tools/adb", 1_000)

        assertEquals(0L, bytes(0))
    }

    @Test
    fun aMissingSdkFolderIsAnEmptyCount() {
        assertEquals(0L, SdkDownloadMonitor(FakeFileSystem()).downloadedBytes("/nowhere", 0))
    }
}
