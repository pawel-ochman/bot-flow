"""Sanity-check this project's Godot web export without executing JavaScript."""
import argparse
import json
import re
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit


class References(HTMLParser):
    def __init__(self):
        super().__init__()
        self.paths = []

    def handle_starttag(self, tag, attrs):
        for key, value in attrs:
            if value and key in ("src", "href"):
                self.paths.append(value)


def require_file(directory, relative):
    path = directory / relative
    if path.is_symlink() or not path.resolve().is_relative_to(directory.resolve()):
        raise ValueError(f"Unsafe artifact path: {relative}")
    if not path.is_file() or path.stat().st_size == 0:
        raise ValueError(f"Missing/empty artifact: {relative}")
    return path


def verify(directory):
    directory = Path(directory)
    for path in directory.rglob("*"):
        if path.is_symlink() or path.is_junction():
            raise ValueError(f"Linked artifact: {path}")
    html = require_file(directory, "index.html").read_text(encoding="utf-8")
    require_file(directory, "index.js")
    with require_file(directory, "index.wasm").open("rb") as stream:
        if stream.read(8) != b"\x00asm\x01\x00\x00\x00":
            raise ValueError("Invalid WebAssembly signature/version")
    with require_file(directory, "index.pck").open("rb") as stream:
        if stream.read(4) != b"GDPC":
            raise ValueError("Invalid Godot PCK signature")
    if not re.search(r"const GODOT_THREADS_ENABLED\s*=\s*false\s*;", html):
        raise ValueError("Expected the single-threaded Godot HTML shell")
    match = re.search(r"const GODOT_CONFIG\s*=\s*(\{[^\n]+\});", html)
    if not match:
        raise ValueError("Missing Godot loader configuration")
    config = json.loads(match.group(1))
    if config.get("executable") != "index":
        raise ValueError("Unexpected loader executable name")
    for name in ("index.wasm", "index.pck"):
        if config.get("fileSizes", {}).get(name) != require_file(directory, name).stat().st_size:
            raise ValueError(f"Loader size mismatch: {name}")
    references = References()
    references.feed(html)
    for reference in references.paths:
        url = urlsplit(reference)
        if url.scheme or url.netloc:
            raise ValueError(f"Unexpected external resource: {reference}")
        if not url.path:
            continue
        if url.path.startswith("/"):
            raise ValueError(f"Root-relative URL will break project Pages hosting: {reference}")
        require_file(directory, unquote(url.path))
    for name in ("index.audio.worklet.js", "index.audio.position.worklet.js"):
        require_file(directory, name)
    return sorted(path.name for path in directory.iterdir() if path.is_file())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    print("Verified web build: " + ", ".join(verify(args.directory)))
