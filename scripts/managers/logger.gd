extends Node
## Logger autoload — gated console logging.
##
## All debug/info print chatter in the project routes through here so that
## release builds and headless script runs (CI / GUT test suite) stay quiet,
## while real errors (printerr) remain visible at all times.
##
## See issue #30: "149 debug print() calls flood console".
##
## The logger deliberately does NOT tag messages — call sites already carry
## their own [DEBUG]/[INFO]/[WARNING] prefixes — it only gates output and
## mirrors every logged line onto the `logged` signal (used by tests).

signal logged(level: String, message: String)

## Master switch. True in the editor and debug builds, false in release
## exports and when running a script headless (e.g. the GUT test suite).
var enabled: bool = false


func _ready():
	enabled = _should_enable()


## Decide whether logging is on for this run.
func _should_enable() -> bool:
	# `-s`/`--script` mode (GUT cmdln, CI, tool scripts) -> stay quiet.
	for arg in OS.get_cmdline_args():
		if arg == "-s" or arg == "--script":
			return false
		if arg.ends_with(".gd") and arg.contains("gut"):
			return false
	return OS.has_feature("editor") or OS.is_debug_build()


func debug(message: String) -> void:
	if not enabled:
		return
	_emit("debug", message)


func info(message: String) -> void:
	if not enabled:
		return
	_emit("info", message)


func warn(message: String) -> void:
	if not enabled:
		return
	_emit("warn", message)


func _emit(level: String, message: String) -> void:
	print(message)
	logged.emit(level, message)
