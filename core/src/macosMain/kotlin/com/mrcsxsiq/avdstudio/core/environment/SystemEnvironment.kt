package com.mrcsxsiq.avdstudio.core.environment

import platform.Foundation.NSHomeDirectory
import platform.Foundation.NSProcessInfo

/** The real process environment and home folder. */
public class SystemEnvironment : Environment {
    override val variables: Map<String, String>
        get() =
            buildMap {
                NSProcessInfo.processInfo.environment.forEach { (key, value) ->
                    if (key is String && value is String) put(key, value)
                }
            }

    override val homeDirectory: String
        get() = NSHomeDirectory()
}
