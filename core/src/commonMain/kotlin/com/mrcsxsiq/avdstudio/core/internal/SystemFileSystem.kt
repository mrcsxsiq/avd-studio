package com.mrcsxsiq.avdstudio.core.internal

import okio.FileSystem

/** The real file system of the current platform. */
internal expect fun systemFileSystem(): FileSystem
