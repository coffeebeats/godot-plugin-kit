#!/usr/bin/env python3
"""bridge.py drives a running game through kit's `system/debug/editor/bridge.gd`.

Requires only the standard library. Run it through `godot-bridge`, which supplies the
interpreter; `bridge/README.md` documents the commands.
"""

import argparse
import contextlib
import hashlib
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time

DEFAULT_PORT = 9080

# NOISE matches the boilerplate every run prints, as the `godot` agent plugin's edit
# hook does; script errors and warnings never match.
NOISE = re.compile(
    r"^Godot Engine v"
    r"|^WARNING: Found older "
    r"|^   at: register_settings"
    r"|^WARNING: \d+ ObjectDB instances were leaked"
    r"|^   at: cleanup "
    r"|^ERROR: \d+ resources still in use at exit"
    r"|^   at: clear "
)

# A line matching this in the game's log means the run is not worth waiting on.
#
# NOTE: The bare `ERROR:` is left out, since `push_error` and the engine's complaints
# about the machine share it and a sandbox provokes the latter on every run. A game that
# dies is caught by its exit instead.
FAILURE = re.compile(r"^(SCRIPT ERROR|SHADER ERROR):")

# How long to leave between liveness checks that cost a process spawn.
LIVENESS_INTERVAL = 2.0


class BridgeError(Exception):
    """BridgeError reports a request the bridge refused, or could not be asked."""


def project_dir():
    """project_dir returns the Godot project's root, or raises if there is none.

    NOTE: The script ships in a plugin, so its own location says nothing about which
    project is driven. A session supplies one; by hand, the working directory does.
    """
    root = os.environ.get("CLAUDE_PROJECT_DIR")
    if root:
        return os.path.abspath(root)

    here = os.path.abspath(os.curdir)
    while True:
        if os.path.isfile(os.path.join(here, "project.godot")):
            return here

        parent = os.path.dirname(here)
        if parent == here:
            raise BridgeError(
                "no 'project.godot' here or above; run it from the project."
            )

        here = parent


def state_dir(port):
    """state_dir returns the temp directory for one project and port's log and pid."""
    key = hashlib.sha256(project_dir().encode("utf-8")).hexdigest()[:12]
    path = os.path.join(tempfile.gettempdir(), f"godot-bridge-{key}-{port}")
    os.makedirs(path, exist_ok=True)
    return path


def log_path(port):
    """log_path returns the file the game's captured output is written to."""
    return os.path.join(state_dir(port), "game.log")


def pid_path(port):
    """pid_path returns the file recording the pid of the game holding the port."""
    return os.path.join(state_dir(port), "game.pid")


def read_pid(port):
    """read_pid returns the pid recorded for the port, or None if there is none."""
    try:
        with open(pid_path(port), encoding="utf-8") as handle:
            return int(handle.read().strip())
    except (OSError, ValueError):
        return None


def request(port, cmd, args=None, timeout=10.0):
    """request sends one command and returns its result, or raises `BridgeError`.

    NOTE: One connection per command, so a client that dies mid-request leaves nothing
    behind for the next one to trip over.
    """
    payload = json.dumps({"cmd": cmd, "args": args or {}}) + "\n"

    try:
        with socket.create_connection(("127.0.0.1", port), timeout=timeout) as conn:
            conn.settimeout(timeout)
            conn.sendall(payload.encode("utf-8"))

            buffer = b""
            while b"\n" not in buffer:
                chunk = conn.recv(65536)
                if not chunk:
                    raise BridgeError("the game closed the connection")
                buffer += chunk
    except (TimeoutError, ConnectionError, OSError) as err:
        raise BridgeError(f"no game answering on port {port} ({err})") from err

    response = json.loads(buffer.split(b"\n", 1)[0].decode("utf-8"))
    if not response.get("ok"):
        raise BridgeError(response.get("error", "unknown error"))

    return response.get("result")


def log_size(port):
    """log_size returns the length of the game's log, or 0 when there is none yet."""
    try:
        return os.path.getsize(log_path(port))
    except OSError:
        return 0


def read_log(port, lines=40, unfiltered=False, offset=0):
    """read_log returns the tail of the game's log, minus the boilerplate.

    NOTE: `offset` skips everything written before it, which keeps a wait from reporting
    an error some earlier command left behind.
    """
    path = log_path(port)
    if not os.path.exists(path):
        return []

    with open(path, encoding="utf-8", errors="replace") as handle:
        handle.seek(offset)
        out = [line.rstrip("\n") for line in handle]

    if not unfiltered:
        out = [line for line in out if line.strip() and not NOISE.search(line)]

    return out[-lines:] if lines > 0 else out


def log_failure(port, offset=0):
    """log_failure returns the first failure the game logged after `offset`, if any."""
    for line in read_log(port, lines=0, offset=offset):
        if FAILURE.search(line):
            return line

    return None


def is_game_process(pid):
    """is_game_process returns whether the pid still names a Godot process.

    NOTE: A pid file outlives the process it names and pids are recycled, so the reaper
    checks the image name before killing anything.
    """
    try:
        if os.name == "nt":
            out = subprocess.run(
                ["tasklist", "/FI", f"PID eq {pid}", "/FO", "CSV", "/NH"],
                capture_output=True,
                text=True,
                timeout=10,
            ).stdout
        else:
            out = subprocess.run(
                ["ps", "-p", str(pid), "-o", "comm="],
                capture_output=True,
                text=True,
                timeout=10,
            ).stdout
    except (OSError, subprocess.SubprocessError):
        return False

    return "godot" in out.lower()


def reap(port):
    """reap stops the bridge-owned game, even if it never opened the port.

    NOTE: An aborted client leaves the previous game holding the port, and the next
    `listen` then fails with `ERR_ALREADY_IN_USE`.
    """
    try:
        request(port, "quit", timeout=2.0)
        time.sleep(1.0)
    except BridgeError:
        pass

    pid = read_pid(port)
    if pid is None:
        if port_is_free(port):
            return
        raise BridgeError(
            f"port {port} is held by a process this script did not start; close the "
            "game started from the editor, or pass a different --port"
        )

    if not is_game_process(pid):
        if port_is_free(port):
            return
        raise BridgeError(f"port {port} is held by an unknown process")

    if os.name == "nt":
        subprocess.run(
            ["taskkill", "/PID", str(pid), "/F"], capture_output=True, timeout=10
        )
    else:
        with contextlib.suppress(OSError):
            os.kill(pid, 15)

    time.sleep(1.0)


def port_is_free(port):
    """port_is_free returns whether nothing is listening on the port."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.settimeout(0.5)
        return probe.connect_ex(("127.0.0.1", port)) != 0


def field_of(value, path):
    """field_of returns a dotted field of a result, or `None` when it is not there."""
    for part in path:
        if not isinstance(value, dict) or part not in value:
            return None
        value = value[part]

    return value


def matches(value, expected):
    """matches returns whether a field's value is what the caller asked to wait for.

    NOTE: `expected` is decoded as JSON when it can be, so `--equals true` matches the
    boolean the game reported rather than the string "True".
    """
    if expected is None:
        return value is True

    try:
        return value == json.loads(expected)
    except ValueError:
        return value == expected


def split_target(target):
    """split_target splits `[<glob>:]<field>` into the node filter and the dotted field.

    NOTE: The glob is optional because a field is usually reported by one node only, and
    naming that node adds nothing. It is there for when two report the same field.
    """
    node, sep, field = target.rpartition(":")
    if not sep:
        node, field = "", target

    if not field:
        raise BridgeError("--for takes [<node glob>:]<field>, e.g. booted or Map:scene")

    return node, field.split(".")


def field_in_state(state, node, field):
    """field_in_state returns the one value `field` has across the reporting nodes.

    It raises when several nodes report the field, since a wait that silently picked one
    of them would pass or hang for reasons the caller cannot see.
    """
    found = {}
    for path, reported in state.items():
        value = field_of(reported, field)
        if value is not None:
            found[path] = value

    if not found:
        where = f" under {node}" if node else ""
        raise BridgeError(f"no node reports {'.'.join(field)}{where}")

    if len(found) > 1:
        raise BridgeError(
            f"{'.'.join(field)} is reported by {len(found)} nodes "
            f"({', '.join(sorted(found))}); narrow it with <node glob>:<field>"
        )

    return next(iter(found.items()))


def log_tail(port, offset, lines=10):
    """log_tail returns the end of the game's log, phrased to append to an error."""
    tail = read_log(port, lines=lines, offset=offset)
    if not tail:
        return ""

    return "\nthe game logged:\n" + "\n".join(tail)


def game_is_gone(port, process, checked_at):
    """game_is_gone returns whether the game has exited, and when it was last asked.

    NOTE: `process` is exact and free, so `launch` passes the handle it already holds.
    A caller which only has the port pays for `tasklist` or `ps`, so it asks rarely.
    """
    if process is not None:
        return process.poll() is not None, checked_at

    now = time.time()
    if now - checked_at < LIVENESS_INTERVAL:
        return False, checked_at

    pid = read_pid(port)

    return pid is not None and not is_game_process(pid), now


def wait_for(port, target, expected, timeout, offset=None, process=None):
    """wait_for polls the game's reported state until a field matches, or gives up once
    the game exits, logs a broken script or shader, or `timeout` seconds pass.

    NOTE: Only what the game logged from `offset` onward counts as a failure, since
    the log outlives the command which wrote it.
    """
    node, field = split_target(target)

    if offset is None:
        offset = log_size(port)

    deadline = time.time() + timeout
    last = "no response yet"
    checked_at = time.time()

    while time.time() < deadline:
        failure = log_failure(port, offset)
        if failure:
            raise BridgeError(f"the game reported an error: {failure}")

        gone, checked_at = game_is_gone(port, process, checked_at)
        if gone:
            raise BridgeError(
                f"the game exited before {target}" + log_tail(port, offset)
            )

        try:
            state = request(
                port, "state", {"filter": [node] if node else []}, timeout=5.0
            )
            path, value = field_in_state(state, node, field)
            if matches(value, expected):
                return state

            last = f"{path} reports {'.'.join(field)} as {value!r}"
        except BridgeError as err:
            last = str(err)

        time.sleep(0.2)

    raise BridgeError(
        f"timed out after {timeout:.0f}s waiting for {target} ({last})"
        + log_tail(port, offset)
    )


def launch(args):
    """launch starts the game with the bridge open, then waits until it is usable."""
    binary = os.environ.get("GODOT") or shutil.which("godot")
    if not binary:
        raise BridgeError("no 'godot' on PATH; set GODOT to the binary")

    reap(args.port)

    command = [binary, "--path", project_dir()]
    if args.scene:
        command.append(args.scene)
    command += ["--", "--bridge-port", str(args.port)]
    command += args.rest

    # NOTE: A detached process writes its errors nowhere the caller can see. Capturing
    # the stream also catches what an in-engine tap cannot, a crash included.
    with open(log_path(args.port), "w", encoding="utf-8", errors="replace") as handle:
        if os.name == "nt":
            flags = subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS
            process = subprocess.Popen(
                command, stdout=handle, stderr=subprocess.STDOUT, creationflags=flags
            )
        else:
            process = subprocess.Popen(
                command, stdout=handle, stderr=subprocess.STDOUT, start_new_session=True
            )

    with open(pid_path(args.port), "w", encoding="utf-8") as pid_file:
        pid_file.write(str(process.pid))

    if args.no_wait:
        return {"pid": process.pid, "log": log_path(args.port)}

    state = wait_for(
        args.port, args.until, args.equals, args.timeout, offset=0, process=process
    )

    return {"pid": process.pid, "log": log_path(args.port), "state": state}


def main(argv=None):
    """main runs the command line and returns the result to print."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--port",
        type=int,
        default=int(os.environ.get("GODOT_DEBUG_BRIDGE_PORT", DEFAULT_PORT)),
        help=f"port the bridge listens on (default: {DEFAULT_PORT})",
    )

    commands = parser.add_subparsers(dest="command", required=True)

    parser_launch = commands.add_parser("launch", help="start the game and wait for it")
    parser_launch.add_argument("--scene", help="scene to run instead of the main scene")
    parser_launch.add_argument("--no-wait", action="store_true", help="do not wait")
    parser_launch.add_argument("--until", default="booted", help="what to wait for")
    parser_launch.add_argument("--equals", help="value to match (default: true)")
    parser_launch.add_argument("--timeout", type=float, default=60.0)
    parser_launch.add_argument("rest", nargs="*", help="extra arguments for the game")

    commands.add_parser("stop", help="shut the game down")
    commands.add_parser("status", help="print the bridge's summary")
    commands.add_parser(
        "reporters", help="list the nodes reporting state, without asking for it"
    )

    parser_tree = commands.add_parser("tree", help="dump part of the scene tree")
    parser_tree.add_argument(
        "--path", default="", help="node to dump, relative to /root"
    )
    parser_tree.add_argument("--depth", type=int, default=3)

    parser_state = commands.add_parser(
        "state", help="report what the game's nodes say about themselves"
    )
    parser_state.add_argument(
        "--filter",
        action="append",
        metavar="GLOB",
        help=(
            "keep only nodes whose path matches; a bare name matches at any depth, "
            "and repeating the flag keeps the union"
        ),
    )

    parser_eval = commands.add_parser("eval", help="evaluate an expression")
    parser_eval.add_argument("expr")

    parser_shot = commands.add_parser("screenshot", help="capture the window")
    parser_shot.add_argument("--out", help="where to write the PNG")
    parser_shot.add_argument("--node", help="crop to this Control, relative to /root")

    parser_logs = commands.add_parser("logs", help="tail the game's output")
    parser_logs.add_argument("--lines", type=int, default=40)
    parser_logs.add_argument("--all", action="store_true", help="do not filter noise")

    parser_wait = commands.add_parser("wait", help="poll until a node reports ready")
    parser_wait.add_argument("--for", dest="target", default="booted")
    parser_wait.add_argument("--equals", help="value to match (default: true)")
    parser_wait.add_argument("--timeout", type=float, default=60.0)

    args = parser.parse_args(argv)

    if args.command == "launch":
        return launch(args)

    if args.command == "logs":
        return read_log(args.port, args.lines, args.all)

    if args.command == "wait":
        return wait_for(args.port, args.target, args.equals, args.timeout)

    if args.command == "stop":
        # NOTE: A graceful quit can close the socket before the client receives its
        # reply, so use the reaper to clean up interrupted sessions.
        return reap(args.port)

    if args.command == "tree":
        return request(args.port, "tree", {"path": args.path, "depth": args.depth})

    if args.command == "state":
        return request(args.port, "state", {"filter": args.filter or []})

    if args.command == "eval":
        return request(args.port, "eval", {"expr": args.expr})

    if args.command == "screenshot":
        out = args.out or os.path.join(
            state_dir(args.port), f"shot-{int(time.time())}.png"
        )
        return request(
            args.port,
            "screenshot",
            {"path": os.path.abspath(out), "node": args.node or ""},
            timeout=15.0,
        )

    return request(args.port, args.command)


if __name__ == "__main__":
    try:
        result = main()
    except BridgeError as error:
        print(f"bridge: {error}", file=sys.stderr)
        sys.exit(1)

    if isinstance(result, list) and all(isinstance(item, str) for item in result):
        print("\n".join(result))
    else:
        print(json.dumps(result, indent=2, sort_keys=True))
