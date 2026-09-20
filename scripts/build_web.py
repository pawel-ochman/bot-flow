"""Build Bot Flow: python scripts/build_web.py (Windows/Linux x86-64, Python 3.12+)."""
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.setup_toolchain import checked_directory, load_lock, prepare, sha256
from tools.verify_web_build import verify

ENGINE_ERROR = re.compile(r"(?:SCRIPT ERROR:|ERROR:)")


def clean_output(root):
    build = checked_directory(root / "build")
    (build / ".gdignore").touch()
    output = build / "web"
    if output.is_symlink() or output.is_junction() or output.resolve() != root.resolve() / "build" / "web":
        raise ValueError(f"Refusing unsafe output directory: {output}")
    if output.exists():
        shutil.rmtree(output)
    output.mkdir()
    return output


def run(command, root, log_name, timeout=300):
    print("Running: " + " ".join(map(str, command)), flush=True)
    try:
        result = subprocess.run(list(map(str, command)), cwd=root, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", timeout=timeout)
    except subprocess.TimeoutExpired as error:
        output = error.stdout or ""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        (root / "build" / log_name).write_text(output + f"\nTimed out after {timeout}s\n", encoding="utf-8")
        raise RuntimeError(f"Required step timed out; see build/{log_name}") from error
    (root / "build" / log_name).write_text(result.stdout, encoding="utf-8")
    print(result.stdout, end="", flush=True)
    if result.returncode or ENGINE_ERROR.search(result.stdout):
        raise RuntimeError(f"Required step failed; see build/{log_name}")
    return result.stdout.strip()


def build(root=ROOT):
    if sys.version_info < (3, 12):
        raise RuntimeError("Python 3.12 or newer is required")
    if shutil.which("git") is None:
        raise RuntimeError("Git must be available on PATH")
    output = clean_output(root)
    godot = prepare(root)
    lock = load_lock(root)
    version = run([godot, "--version"], root, "version.log")
    if version.split(".")[:4] != (lock["godot_version"] + ".stable").split("."):
        raise RuntimeError(f"Unexpected Godot version: {version}")
    run([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_build_tools.py"], root, "build-tools.log")
    common = [godot, "--headless", "--path", root]
    run(common + ["--import"], root, "import.log")
    run(common + ["--script", "tests/run.gd"], root, "tests.log")
    run(common + ["--script", "tools/validate_levels.gd"], root, "levels.log")
    run(common + ["--export-release", "Web", output / "index.html"], root, "export.log")
    files = verify(output)
    revision = subprocess.run(["git", "rev-parse", "HEAD"], cwd=root, capture_output=True, text=True)
    dirty = subprocess.run(["git", "status", "--porcelain"], cwd=root, capture_output=True, text=True)
    top = subprocess.run(["git", "rev-parse", "--show-toplevel"], cwd=root, capture_output=True, text=True)
    owns_repository = top.returncode == 0 and Path(top.stdout.strip()).resolve() == root.resolve()
    metadata = {
        "commit": revision.stdout.strip() if owns_repository and revision.returncode == 0 else None,
        "dirty": bool(dirty.stdout.strip()) if owns_repository and dirty.returncode == 0 else None,
        "godot": version,
        "python": sys.version.split()[0],
        "sha256": {name: sha256(output / name) for name in files},
    }
    (output / "build-info.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(f"Verified Web build: {output}")


if __name__ == "__main__":
    try:
        build()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Build failed: {error}", file=sys.stderr)
        sys.exit(1)
