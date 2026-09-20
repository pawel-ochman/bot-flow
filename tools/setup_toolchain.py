"""Fetch checksum-locked official Godot archives without installing system-wide."""
import hashlib
import json
import platform
import shutil
import urllib.request
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]


def load_lock(root=ROOT):
    return json.loads((root / "tools/toolchain.json").read_text(encoding="utf-8"))


def checked_directory(path):
    if path.is_symlink() or path.is_junction():
        raise ValueError(f"Refusing linked directory: {path}")
    path.mkdir(parents=True, exist_ok=True)
    return path


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def verify_checksum(path, expected):
    if path.is_symlink() or sha256(path) != expected:
        raise ValueError(f"Checksum mismatch: {path.name}. Remove the archive and retry; do not bypass verification.")


def download_archive(directory, spec, base_url):
    path = directory / spec["archive"]
    if not path.exists():
        temporary = path.with_suffix(path.suffix + ".part")
        if temporary.is_symlink():
            raise ValueError(f"Refusing linked download: {temporary}")
        print(f"Downloading {spec['archive']}", flush=True)
        request = urllib.request.Request(base_url + spec["archive"], headers={"User-Agent": "BotFlow-build"})
        try:
            with urllib.request.urlopen(request, timeout=120) as source, temporary.open("wb") as target:
                shutil.copyfileobj(source, target)
            verify_checksum(temporary, spec["sha256"])
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)
    verify_checksum(path, spec["sha256"])
    return path


def extract_templates(archive_path, destination, lock):
    verify_checksum(archive_path, lock["templates"]["sha256"])
    with ZipFile(archive_path) as archive:
        version = archive.read("templates/version.txt").decode().strip()
        if version != lock["godot_version"] + ".stable":
            raise ValueError(f"Wrong template version: {version}")
        for name in ("web_nothreads_debug.zip", "web_nothreads_release.zip"):
            target = destination / name
            if target.is_symlink():
                raise ValueError(f"Refusing linked template: {target}")
            target.write_bytes(archive.read("templates/" + name))


def prepare(root=ROOT):
    lock = load_lock(root)
    system = platform.system()
    if system not in lock["editors"] or platform.machine().lower() not in ("amd64", "x86_64"):
        raise ValueError("Automatic setup supports Windows/Linux x86-64 with Python 3.12+. No engine upgrade was attempted.")
    directory = checked_directory(root / ".tools")
    (directory / ".gdignore").touch()
    downloads = checked_directory(directory / "downloads")
    editor_dir = checked_directory(directory / "godot")
    editor = lock["editors"][system]
    archive_path = download_archive(downloads, editor, lock["base_url"])
    # Extract only fixed members, never arbitrary archive paths.
    with ZipFile(archive_path) as archive:
        for name in editor["members"]:
            if Path(name).name != name:
                raise ValueError("Editor archive member must be a filename")
            target = editor_dir / name
            if target.is_symlink():
                raise ValueError(f"Refusing linked executable: {target}")
            target.write_bytes(archive.read(name))
            target.chmod(0o755)
    template_archive = download_archive(downloads, lock["templates"], lock["base_url"])
    extract_templates(template_archive, directory, lock)
    return editor_dir / editor["executable"]


if __name__ == "__main__":
    print(prepare())
