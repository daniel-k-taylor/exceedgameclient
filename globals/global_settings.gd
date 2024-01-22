extends Node

const ReleaseLoggingEnabled = true # If true, log even on release builds.
const UseAzureServerAlways = true # If true, always defaults to the azure server.
var MuteEmotes = false

func is_logging_enabled() -> bool:
	if ReleaseLoggingEnabled:
		return true
	return OS.is_debug_build()

func get_server_url() -> String:
	const azure_url = "wss://fightingcardslinux.azurewebsites.net"
	const local_url = "ws://localhost:8080"
	if UseAzureServerAlways or not OS.is_debug_build():
		return azure_url
	else:
		return local_url
