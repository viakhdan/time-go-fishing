"""Build every export preset and pack itch.io-ready zips (DESIGN.md §13 Day 7).

Runs Godot headless for each preset in export_presets.cfg, then zips each
platform into build/itch/:
    TimeGoFishing-windows.zip   TimeGoFishing-linux.zip
    TimeGoFishing-macos.zip     TimeGoFishing-web.zip  (index.html at the root,
                                                        upload as "HTML" on itch.io)
Needs the Godot 4.7.2 export templates installed.

Usage:
    python tools/export_all.py [--only Web] [--debug]
Set GODOT to the console executable if it isn't at the default path.
"""
import argparse
import os
import shutil
import subprocess
import sys
import zipfile

DEFAULT_GODOT = r"C:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# preset name -> (export path, itch zip name)
PRESETS = {
    "Windows Desktop": ("build/windows/TimeGoFishing.exe", "windows"),
    "Linux": ("build/linux/TimeGoFishing.x86_64", "linux"),
    "macOS": ("build/macos/TimeGoFishing.zip", "macos"),
    "Web": ("build/web/index.html", "web"),
}


def export(godot, preset, path, debug):
    out_dir = os.path.join(ROOT, os.path.dirname(path))
    shutil.rmtree(out_dir, ignore_errors=True)
    os.makedirs(out_dir)
    # Keep the open editor from importing build output (it would add .import files).
    open(os.path.join(ROOT, "build", ".gdignore"), "a").close()
    mode = "--export-debug" if debug else "--export-release"
    proc = subprocess.run([godot, "--headless", "--path", ROOT, mode, preset, os.path.join(ROOT, path)],
                          capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=900)
    output = proc.stdout + proc.stderr
    errors = [l for l in output.splitlines() if "ERROR" in l]
    ok = proc.returncode == 0 and os.path.exists(os.path.join(ROOT, path)) and not errors
    return ok, output


def pack(path, name):
    """Zips the platform folder. macOS is already a zip from Godot."""
    itch = os.path.join(ROOT, "build", "itch")
    os.makedirs(itch, exist_ok=True)
    target = os.path.join(itch, f"TimeGoFishing-{name}.zip")
    src = os.path.join(ROOT, path)
    if src.endswith(".zip"):
        shutil.copyfile(src, target)
        return target
    folder = os.path.dirname(src)
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(os.listdir(folder)):
            if not f.endswith(".import"):
                z.write(os.path.join(folder, f), f)
    return target


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", help="export just this preset name")
    ap.add_argument("--debug", action="store_true", help="debug export (adds a console wrapper on Windows)")
    args = ap.parse_args()
    godot = os.environ.get("GODOT", DEFAULT_GODOT)
    subprocess.run([godot, "--headless", "--path", ROOT, "--import"], capture_output=True, timeout=600)

    failed = []
    for preset, (path, name) in PRESETS.items():
        if args.only and preset != args.only:
            continue
        ok, output = export(godot, preset, path, args.debug)
        if not ok:
            failed.append(preset)
            print(f"✗ {preset}\n{output.strip()}\n")
            continue
        zip_path = pack(path, name)
        print(f"✓ {preset:16} {os.path.relpath(zip_path, ROOT)}  ({os.path.getsize(zip_path) / 1e6:.1f} MB)")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
