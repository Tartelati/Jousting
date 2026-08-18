extends GutTest
# ============================================================
# Unit tests for the Logger autoload (gated console logging).
# Verifies the gate: silent when disabled, signal-emitted when
# enabled, and off by default in headless/script-mode runs.
# ============================================================

func test_logger_disabled_in_script_mode():
	# CI / GUT run via `-s`, so the logger must be off by default there.
	assert_false(Logger.enabled, "logger stays quiet during test runs")


func test_debug_emits_signal_when_enabled():
	watch_signals(Logger)
	Logger.enabled = true

	Logger.debug("hello world")

	assert_signal_emitted_with_parameters(Logger, "logged", ["debug", "hello world"])
	Logger.enabled = false


func test_info_emits_signal_when_enabled():
	watch_signals(Logger)
	Logger.enabled = true

	Logger.info("wave %d ready" % 5)

	assert_signal_emitted_with_parameters(Logger, "logged", ["info", "wave 5 ready"])
	Logger.enabled = false


func test_logging_silent_when_disabled():
	watch_signals(Logger)
	Logger.enabled = false

	Logger.debug("should not be logged")
	Logger.info("neither should this")

	assert_signal_not_emitted(Logger, "logged")
