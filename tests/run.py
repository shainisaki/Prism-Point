#!/usr/bin/env python3
"""Godot may exit 0 after script errors: treat its error diagnostics as failures."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

project = Path(__file__).resolve().parents[1]
godot = shutil.which("godot") or shutil.which("godot4")
if not godot:
    sys.exit("Godot 4.6+ fehlt im PATH.")

with tempfile.TemporaryDirectory(prefix="prism-tests-") as temporary:
    environment = os.environ.copy()
    for suffix in ("DATA", "CONFIG", "CACHE"):
        environment[f"XDG_{suffix}_HOME"] = str(Path(temporary) / suffix.lower())
    for arguments in (["--editor", "--import", "--quit"], ["--script", "tests/smoke.gd"], ["--script", "tests/feedback.gd"], ["--script", "tests/feel.gd"], ["--script", "tests/options.gd"], ["--script", "tests/spatial.gd"]):
        try:
            result = subprocess.run(
                [godot, "--headless", "--path", str(project), *arguments],
                env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, timeout=120,
            )
        except subprocess.TimeoutExpired as error:
            output = error.stdout or b""
            print(output.decode(errors="replace") if isinstance(output, bytes) else output)
            sys.exit("Godot test timed out; see diagnostics above.")
        print(result.stdout, end="")
        if result.returncode or re.search(r"(?:SCRIPT ERROR:|(?:^|\n)ERROR:|FAIL:)", result.stdout):
            sys.exit(result.returncode or 1)
        if "--script" in arguments and not re.search(r"RESULT: [1-9]\d* checks, 0 failures", result.stdout):
            sys.exit("Test suite did not complete.")
print("Godot import and native gameplay tests passed without engine errors.")
