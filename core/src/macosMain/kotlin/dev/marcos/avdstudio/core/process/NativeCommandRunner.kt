@file:OptIn(ExperimentalForeignApi::class, BetaInteropApi::class)

package dev.marcos.avdstudio.core.process

import kotlinx.cinterop.BetaInteropApi
import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.ObjCObjectVar
import kotlinx.cinterop.alloc
import kotlinx.cinterop.memScoped
import kotlinx.cinterop.ptr
import kotlinx.cinterop.value
import platform.Foundation.NSError
import platform.Foundation.NSFileHandle
import platform.Foundation.NSFileManager
import platform.Foundation.NSProcessInfo
import platform.Foundation.NSString
import platform.Foundation.NSTask
import platform.Foundation.NSTemporaryDirectory
import platform.Foundation.NSURL
import platform.Foundation.NSUTF8StringEncoding
import platform.Foundation.NSUUID
import platform.Foundation.closeFile
import platform.Foundation.fileHandleForWritingAtPath
import platform.Foundation.fileHandleWithNullDevice
import platform.Foundation.stringWithContentsOfFile
import platform.Foundation.waitUntilExit

/**
 * [CommandRunner] backed by Foundation's `NSTask`.
 *
 * Output goes to temporary files rather than pipes so that a chatty process can never
 * deadlock against a full pipe buffer while we wait for it to exit.
 */
public class NativeCommandRunner : CommandRunner {
    override fun run(command: Command): CommandResult {
        val outputPath = temporaryPath("out")
        val errorPath = temporaryPath("err")
        val fileManager = NSFileManager.defaultManager
        try {
            fileManager.createFileAtPath(outputPath, null, null)
            fileManager.createFileAtPath(errorPath, null, null)
            val outputHandle = NSFileHandle.fileHandleForWritingAtPath(outputPath)
            val errorHandle = NSFileHandle.fileHandleForWritingAtPath(errorPath)

            val task = makeTask(command)
            task.standardOutput = outputHandle
            task.standardError = errorHandle
            task.standardInput = NSFileHandle.fileHandleWithNullDevice
            start(task, command)
            task.waitUntilExit()
            outputHandle?.closeFile()
            errorHandle?.closeFile()

            return CommandResult(
                exitCode = task.terminationStatus,
                standardOutput = readText(outputPath),
                standardError = readText(errorPath),
            )
        } finally {
            fileManager.removeItemAtPath(outputPath, null)
            fileManager.removeItemAtPath(errorPath, null)
        }
    }

    override fun launchDetached(command: Command): Int {
        val task = makeTask(command)
        task.standardOutput = NSFileHandle.fileHandleWithNullDevice
        task.standardError = NSFileHandle.fileHandleWithNullDevice
        task.standardInput = NSFileHandle.fileHandleWithNullDevice
        start(task, command)
        return task.processIdentifier
    }

    private fun makeTask(command: Command): NSTask {
        if (!NSFileManager.defaultManager.isExecutableFileAtPath(command.executable)) {
            throw CommandException("Cannot execute ${command.executable}: file not found or not executable.")
        }
        val task = NSTask()
        task.executableURL = NSURL.fileURLWithPath(command.executable)
        task.arguments = command.arguments
        task.environment =
            buildMap<Any?, Any?> {
                putAll(NSProcessInfo.processInfo.environment)
                putAll(command.environment)
            }
        command.workingDirectory?.let { task.currentDirectoryURL = NSURL.fileURLWithPath(it) }
        return task
    }

    private fun start(
        task: NSTask,
        command: Command,
    ) = memScoped {
        val error = alloc<ObjCObjectVar<NSError?>>()
        if (!task.launchAndReturnError(error.ptr)) {
            throw CommandException("Failed to start ${command.executable}: ${error.value?.localizedDescription}")
        }
    }

    private fun readText(path: String): String = NSString.stringWithContentsOfFile(path, NSUTF8StringEncoding, null) ?: ""

    private fun temporaryPath(suffix: String): String = NSTemporaryDirectory() + "avdstudio-" + NSUUID().UUIDString() + "." + suffix
}
