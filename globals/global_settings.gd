extends Node

const ReleaseLoggingEnabled = true # If true, log even on release builds.

func is_logging_enabled() -> bool:
	if ReleaseLoggingEnabled:
		return true
	return OS.is_debug_build()
