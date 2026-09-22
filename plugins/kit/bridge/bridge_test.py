"""Tests for how the bridge decides a run is not worth waiting on."""

import tempfile
import time
import unittest
from unittest import mock

import bridge

# Two lines a sandboxed harness provokes on a run that is otherwise healthy.
SANDBOX_LOG = [
    "ERROR: Failed to open 'user://logs/godot2026-09-22T14.14.31.log'.",
    "   at: copy (core/io/dir_access.cpp:429)",
    "ERROR: Failed to read the root certificate store.",
    "   at: get_system_ca_certificates (platform/windows/os_windows.cpp:2582)",
]


class StateTestCase(unittest.TestCase):
    """StateTestCase points the bridge's log and pid files at a throwaway directory."""

    def setUp(self):
        self._dir = tempfile.TemporaryDirectory()
        self.addCleanup(self._dir.cleanup)

        state = mock.patch.object(bridge, "state_dir", return_value=self._dir.name)
        state.start()
        self.addCleanup(state.stop)

        self.port = 9099

    def write_log(self, lines):
        """write_log puts `lines` where the bridge reads the game's output."""
        with open(bridge.log_path(self.port), "w", encoding="utf-8") as handle:
            handle.write("\n".join(lines) + "\n")


class FailureTest(unittest.TestCase):
    """FailureTest covers which log lines end a wait."""

    def test_failure_broken_script_matches(self):
        # Given: The label the engine reserves for a script it could not run.
        line = "SCRIPT ERROR: Parse Error: Identifier 'foo' not declared."

        # Then: It ends the wait.
        self.assertIsNotNone(bridge.FAILURE.search(line))

    def test_failure_broken_shader_matches(self):
        # Given: The label the engine reserves for a shader it could not compile.
        line = "SHADER ERROR: Invalid assignment of 'vec3' to 'vec4'."

        # Then: It ends the wait.
        self.assertIsNotNone(bridge.FAILURE.search(line))

    def test_failure_engine_environment_line_ignored(self):
        # Given: The bare label, which a sandbox provokes on every run.
        for line in SANDBOX_LOG:
            with self.subTest(line=line):
                # Then: It does not end the wait.
                self.assertIsNone(bridge.FAILURE.search(line))

    def test_failure_warning_ignored(self):
        # Given: A warning, which says nothing about whether the run continues.
        line = "WARNING: Cannot resolve the uid."

        # Then: It does not end the wait.
        self.assertIsNone(bridge.FAILURE.search(line))


class LogTest(StateTestCase):
    """LogTest covers reading the game's captured output."""

    def test_log_failure_line_after_offset_reported(self):
        # Given: A log whose only script error follows an earlier one.
        self.write_log(
            [
                "SCRIPT ERROR: stale, from a previous run.",
                "MARK",
                "SCRIPT ERROR: the one this wait should report.",
            ]
        )
        offset = len("SCRIPT ERROR: stale, from a previous run.\n")

        # When: The wait scans from after the stale line.
        failure = bridge.log_failure(self.port, offset)

        # Then: It names the new one.
        self.assertEqual(failure, "SCRIPT ERROR: the one this wait should report.")

    def test_log_failure_sandboxed_run_finds_none(self):
        # Given: A log carrying only what a sandbox provokes.
        self.write_log(SANDBOX_LOG)

        # Then: Nothing ends the wait.
        self.assertIsNone(bridge.log_failure(self.port, 0))

    def test_log_tail_declined_lines_included(self):
        # Given: The same log, which the wait declined to fail on.
        self.write_log(SANDBOX_LOG)

        # When: A wait gives up and reports itself.
        tail = bridge.log_tail(self.port, 0)

        # Then: The engine's lines are in the report.
        self.assertIn("Failed to read the root certificate store.", tail)

    def test_log_tail_missing_log_is_empty(self):
        # Given: No log at all, as before the game has written anything.
        # Then: The error the caller sees gains nothing rather than an empty heading.
        self.assertEqual(bridge.log_tail(self.port, 0), "")


class LivenessTest(StateTestCase):
    """LivenessTest covers noticing the game exited rather than inferring it."""

    def test_game_is_gone_exited_handle_reports_at_once(self):
        # Given: The handle `launch` holds, for a game that has exited.
        process = mock.Mock()
        process.poll.return_value = 1

        # Then: The exit is seen without waiting out the timeout.
        gone, _ = bridge.game_is_gone(self.port, process, 0.0)
        self.assertTrue(gone)

    def test_game_is_gone_running_handle_keeps_waiting(self):
        # Given: The same handle, for a game still running.
        process = mock.Mock()
        process.poll.return_value = None

        # Then: The wait continues.
        gone, _ = bridge.game_is_gone(self.port, process, 0.0)
        self.assertFalse(gone)

    def test_game_is_gone_recent_check_skips_the_spawn(self):
        # Given: No handle, and a check made a moment ago.
        checked = time.time()

        with mock.patch.object(bridge, "is_game_process") as asked:
            # When: The wait asks again.
            gone, checked_at = bridge.game_is_gone(self.port, None, checked)

        # Then: The run is not declared dead, and no process is spawned to ask.
        self.assertFalse(gone)
        asked.assert_not_called()

        # Then: The earlier check still sets when the next one is due.
        self.assertEqual(checked_at, checked)

    def test_game_is_gone_without_pid_file_keeps_waiting(self):
        # Given: A game started from the editor, which records no pid.
        with mock.patch.object(bridge, "port_is_free", return_value=True):
            # When: The wait asks whether it is still there.
            gone, _ = bridge.game_is_gone(self.port, None, 0.0)

        # Then: The wait continues rather than reporting an exit.
        self.assertFalse(gone)


if __name__ == "__main__":
    unittest.main()
