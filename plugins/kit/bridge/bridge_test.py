"""Tests for how the bridge decides a run is not worth waiting on.

Run them from the repository root:

    python -m unittest discover -s plugins/kit/bridge -p "*_test.py"

NOTE: The cases below pin the distinction the bridge cannot make by prefix alone — the
engine labels its own trouble and the game's alike — so they are the record of why
`FAILURE` is narrow and why the exit is checked separately.
"""

import os
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


class FailureTest(unittest.TestCase):
    """FailureTest covers which log lines end a wait."""

    def test_failure_broken_script_matches(self):
        # Given: the label the engine reserves for a script it could not run.
        line = "SCRIPT ERROR: Parse Error: Identifier 'foo' not declared."

        # Then: it ends the wait.
        self.assertIsNotNone(bridge.FAILURE.search(line))

    def test_failure_broken_shader_matches(self):
        # Given: the label the engine reserves for a shader it could not compile.
        line = "SHADER ERROR: Invalid assignment of 'vec3' to 'vec4'."

        # Then: it ends the wait.
        self.assertIsNotNone(bridge.FAILURE.search(line))

    def test_failure_engine_environment_line_ignored(self):
        # Given: the bare label, which `push_error` and the engine's core both print.
        for line in SANDBOX_LOG:
            with self.subTest(line=line):
                # Then: it does not end the wait, or no launch under a sandbox survives.
                self.assertIsNone(bridge.FAILURE.search(line))

    def test_failure_warning_ignored(self):
        # Given: a warning, which says nothing about whether the run continues.
        line = "WARNING: Cannot resolve the uid."

        # Then: it does not end the wait.
        self.assertIsNone(bridge.FAILURE.search(line))


class LogTest(unittest.TestCase):
    """LogTest covers reading the game's captured output."""

    def setUp(self):
        self._dir = tempfile.TemporaryDirectory()
        self.addCleanup(self._dir.cleanup)

        # Given: a project, which is all `state_dir` needs to place the log.
        with open(os.path.join(self._dir.name, "project.godot"), "w"):
            pass

        env = mock.patch.dict(os.environ, {"CLAUDE_PROJECT_DIR": self._dir.name})
        env.start()
        self.addCleanup(env.stop)

        self.port = 9099

    def write_log(self, lines):
        """write_log puts `lines` where the bridge reads the game's output."""
        with open(bridge.log_path(self.port), "w", encoding="utf-8") as handle:
            handle.write("\n".join(lines) + "\n")

    def test_log_failure_line_after_offset_reported(self):
        # Given: a log whose only script error follows an earlier one.
        self.write_log(
            [
                "SCRIPT ERROR: stale, from a previous run.",
                "MARK",
                "SCRIPT ERROR: the one this wait should report.",
            ]
        )
        offset = len("SCRIPT ERROR: stale, from a previous run.\n")

        # When: the wait scans from after the stale line.
        failure = bridge.log_failure(self.port, offset)

        # Then: it names the new one, since the log outlives the command that wrote it.
        self.assertEqual(failure, "SCRIPT ERROR: the one this wait should report.")

    def test_log_failure_sandboxed_run_finds_none(self):
        # Given: a log carrying only what a sandbox provokes.
        self.write_log(SANDBOX_LOG)

        # Then: nothing ends the wait.
        self.assertIsNone(bridge.log_failure(self.port, 0))

    def test_log_tail_declined_lines_included(self):
        # Given: the same log, which the wait declined to fail on.
        self.write_log(SANDBOX_LOG)

        # When: a wait gives up and reports itself.
        tail = bridge.log_tail(self.port, 0)

        # Then: the engine's lines are in it, so nothing is hidden from the caller.
        self.assertIn("Failed to read the root certificate store.", tail)

    def test_log_tail_missing_log_is_empty(self):
        # Given: no log at all, as before the game has written anything.
        # Then: the error the caller sees gains nothing rather than an empty heading.
        self.assertEqual(bridge.log_tail(self.port, 0), "")


class LivenessTest(unittest.TestCase):
    """LivenessTest covers noticing the game exited rather than inferring it."""

    def test_game_is_gone_exited_handle_reports_at_once(self):
        # Given: the handle `launch` holds, for a game that has exited.
        process = mock.Mock()
        process.poll.return_value = 1

        # Then: the exit is seen without waiting out the timeout.
        gone, _ = bridge.game_is_gone(9099, process, 0.0)
        self.assertTrue(gone)

    def test_game_is_gone_running_handle_keeps_waiting(self):
        # Given: the same handle, for a game still running.
        process = mock.Mock()
        process.poll.return_value = None

        # Then: the wait continues.
        gone, _ = bridge.game_is_gone(9099, process, 0.0)
        self.assertFalse(gone)

    def test_game_is_gone_recent_check_skips_the_spawn(self):
        # Given: no handle, and a check made a moment ago.
        with mock.patch.object(bridge, "is_game_process") as asked:
            gone, checked_at = bridge.game_is_gone(9099, None, time.time())

            # Then: the run is not declared dead, and no process is spawned to ask.
            self.assertFalse(gone)
            asked.assert_not_called()
            self.assertGreater(checked_at, 0.0)

    def test_game_is_gone_without_pid_file_keeps_waiting(self):
        # Given: a game started from the editor, which records no pid.
        with mock.patch.object(bridge, "read_pid", return_value=None):
            # Then: `wait` against it keeps waiting rather than reporting an exit.
            gone, _ = bridge.game_is_gone(9099, None, 0.0)
            self.assertFalse(gone)


if __name__ == "__main__":
    unittest.main()
