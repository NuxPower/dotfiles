#!/usr/bin/env python3
"""Keep numbered workspaces 1-5 on the laptop and 6+ on the external screen."""
import fcntl
import json
import os
from pathlib import Path
import socket
import subprocess
import time

LAPTOP = "AU Optronics 0x71EC"
EXTERNAL = "HKC OVERSEAS LIMITED G2411P 0000000000001"


def hyprctl(*args):
    result = subprocess.run(
        ["hyprctl", *args], capture_output=True, text=True, timeout=5, check=True
    )
    return result.stdout


def arrange():
    monitors = {m["description"]: m["name"] for m in json.loads(hyprctl("monitors", "-j"))}
    # Leave workspaces available on the remaining screen when one is disconnected.
    if LAPTOP not in monitors or EXTERNAL not in monitors:
        return
    for workspace in json.loads(hyprctl("workspaces", "-j")):
        number = workspace["id"]
        if number <= 0:
            continue  # Leave named and special workspaces alone.
        target = monitors[LAPTOP if number <= 5 else EXTERNAL]
        if workspace["monitor"] != target:
            hyprctl("dispatch", "moveworkspacetomonitor", f"{number} {target}")


def main():
    instance = Path(os.environ["XDG_RUNTIME_DIR"]) / "hypr" / os.environ["HYPRLAND_INSTANCE_SIGNATURE"]
    with (instance / ".workspace-monitors.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as events:
            for attempt in range(20):
                try:
                    events.connect(str(instance / ".socket2.sock"))
                    break
                except (FileNotFoundError, ConnectionRefusedError):
                    if attempt == 19:
                        raise
                    time.sleep(0.25)
            arrange()
            pending = b""
            while chunk := events.recv(65536):
                pending += chunk
                while b"\n" in pending:
                    line, pending = pending.split(b"\n", 1)
                    event = line.split(b">>", 1)[0]
                    if event in (b"createworkspacev2", b"moveworkspacev2", b"monitoraddedv2", b"configreloaded"):
                        try:
                            arrange()
                        except (OSError, subprocess.SubprocessError, json.JSONDecodeError) as error:
                            print(f"Workspace monitor routing: {error}", flush=True)


if __name__ == "__main__":
    main()
