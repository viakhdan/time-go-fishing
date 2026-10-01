"""Run the Godot test suites headless and fail on any failed check or script error.

GDScript runtime errors abort a test without failing it, so this wrapper also
treats any "SCRIPT ERROR" / "ERROR:" line in Godot's output as a failure.

Usage:
    python tools/run_tests.py
Set GODOT to the console executable if it isn't at the default path.
"""
import os
import re
import subprocess
import sys

DEFAULT_GODOT = r"C:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
# Engine shutdown noise that isn't caused by our code.
IGNORED = re.compile(r"leaked at exit|Pages in use exist at exit|Unreferenced static string|wait_to_finish|~Thread|~PagedAllocator|string_name\.cpp")


def main():
    godot = os.environ.get("GODOT", DEFAULT_GODOT)
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    subprocess.run([godot, "--headless", "--path", root, "--import"], capture_output=True, timeout=300)
    proc = subprocess.run(
        [godot, "--headless", "--path", root, "res://tests/TestRunner.tscn"],
        capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300,
    )
    output = proc.stdout + proc.stderr
    lines = [l for l in output.splitlines() if not l.startswith("Godot Engine")]
    errors = [l for l in lines if ("SCRIPT ERROR" in l or l.startswith("ERROR:")) and not IGNORED.search(l)]
    print("\n".join(lines).strip())
    if errors:
        print(f"\n{len(errors)} engine/script error(s) — treating as failure.")
    sys.exit(1 if proc.returncode != 0 or errors else 0)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
