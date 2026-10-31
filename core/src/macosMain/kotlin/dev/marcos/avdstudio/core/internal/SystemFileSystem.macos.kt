package dev.marcos.avdstudio.core.internal

import okio.FileSystem

internal actual fun systemFileSystem(): FileSystem = FileSystem.SYSTEM
