"""Failure-path tests for the delivery tooling, using no network or game engine."""
import contextlib
import hashlib
import io
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts import build_web
from tools import setup_toolchain
from tools.verify_web_build import verify


class BuildToolsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.output = build_web.clean_output(self.root)

    def artifact(self):
        files = {
            "index.js": b"loader", "index.wasm": b"\x00asm\x01\x00\x00\x00",
            "index.pck": b"GDPC", "index.png": b"image",
            "index.audio.worklet.js": b"audio", "index.audio.position.worklet.js": b"position",
        }
        for name, contents in files.items():
            (self.output / name).write_bytes(contents)
        config = {"executable": "index", "fileSizes": {"index.wasm": 8, "index.pck": 4}}
        html = '<script src="index.js"></script><img src="index.png">\n'
        html += 'const GODOT_THREADS_ENABLED = false;\nconst GODOT_CONFIG = ' + json.dumps(config) + ';\n'
        (self.output / "index.html").write_text(html, encoding="utf-8")

    def test_valid_artifact(self):
        self.artifact()
        self.assertIn("index.wasm", verify(self.output))

    def test_missing_required_file(self):
        for name in ("index.html", "index.js", "index.wasm", "index.pck", "index.png", "index.audio.worklet.js"):
            with self.subTest(name=name):
                self.artifact()
                (self.output / name).unlink()
                with self.assertRaises(ValueError):
                    verify(self.output)

    def test_empty_required_file(self):
        self.artifact()
        (self.output / "index.js").write_bytes(b"")
        with self.assertRaisesRegex(ValueError, "empty"):
            verify(self.output)

    def test_binary_signatures(self):
        for name in ("index.wasm", "index.pck"):
            self.artifact()
            (self.output / name).write_bytes(b"corrupt")
            with self.assertRaisesRegex(ValueError, "signature"):
                verify(self.output)

    def test_loader_size_mismatch(self):
        self.artifact()
        with (self.output / "index.pck").open("ab") as stream:
            stream.write(b"extra")
        with self.assertRaisesRegex(ValueError, "size mismatch"):
            verify(self.output)

    def test_threaded_build_rejected(self):
        self.artifact()
        html = self.output / "index.html"
        html.write_text(html.read_text().replace("false", "true"))
        with self.assertRaisesRegex(ValueError, "single-threaded"):
            verify(self.output)

    def test_unsafe_or_nonportable_references(self):
        for reference in ("/index.js", "../outside.js", "https://example.org/script.js", "%2e%2e/outside.js"):
            self.artifact()
            html = self.output / "index.html"
            html.write_text(html.read_text().replace('src="index.js"', f'src="{reference}"'))
            with self.assertRaises(ValueError):
                verify(self.output)

    def test_only_designated_output_is_cleaned(self):
        marker = self.root / "build/keep.log"
        marker.write_text("preserve")
        (self.output / "stale.js").write_text("stale")
        build_web.clean_output(self.root)
        self.assertTrue(marker.exists())
        self.assertEqual(list(self.output.iterdir()), [])

    def test_linked_output_refused_before_deletion(self):
        # Mock the link predicate on Windows where symlink creation needs privileges.
        with patch.object(Path, "is_symlink", return_value=True):
            with self.assertRaisesRegex(ValueError, "linked"):
                build_web.clean_output(self.root)

    def test_checksum_mismatch_is_fatal(self):
        archive = self.root / "archive.zip"
        archive.write_bytes(b"unexpected bytes")
        with self.assertRaisesRegex(ValueError, "Checksum mismatch"):
            setup_toolchain.verify_checksum(archive, "0" * 64)

    def test_cached_archive_is_reverified_without_network(self):
        archive = self.root / "archive.zip"
        archive.write_bytes(b"pinned bytes")
        spec = {"archive": archive.name, "sha256": hashlib.sha256(b"pinned bytes").hexdigest()}
        with patch("urllib.request.urlopen") as network:
            self.assertEqual(setup_toolchain.download_archive(self.root, spec, "https://invalid/"), archive)
            network.assert_not_called()
            archive.write_bytes(b"tampered")
            with self.assertRaises(ValueError):
                setup_toolchain.download_archive(self.root, spec, "https://invalid/")

    def test_nonzero_process_fails(self):
        self.check_process_failure(1, "failed test")

    def test_timeout_preserves_diagnostics(self):
        failure = subprocess.TimeoutExpired("engine", 3, output=b"last engine message\n")
        with patch("subprocess.run", side_effect=failure), contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(RuntimeError, "timed out"):
                build_web.run(["engine"], self.root, "timeout.log", timeout=3)
        log = (self.root / "build/timeout.log").read_text()
        self.assertIn("last engine message", log)
        self.assertIn("Timed out after 3s", log)

    def test_zero_exit_with_engine_error_fails(self):
        self.check_process_failure(0, "SCRIPT ERROR: could not compile")
        self.check_process_failure(0, "ERROR: missing resource")

    def check_process_failure(self, code, output):
        with patch("subprocess.run", return_value=subprocess.CompletedProcess([], code, output)), contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(RuntimeError):
                build_web.run(["engine"], self.root, "failed.log")
        self.assertEqual((self.root / "build/failed.log").read_text(), output)

    def test_failed_checks_prevent_export(self):
        calls = []

        def fake_run(command, root, log_name, timeout=300):
            calls.append(log_name)
            if log_name == "tests.log":
                raise RuntimeError("Game tests failed")
            return "4.7.2.stable.official.test" if log_name == "version.log" else "PASS"

        with patch.object(build_web, "prepare", return_value=Path("godot")), \
             patch.object(build_web, "load_lock", return_value={"godot_version": "4.7.2"}), \
             patch.object(build_web, "run", side_effect=fake_run):
            with self.assertRaises(RuntimeError):
                build_web.build(self.root)
        self.assertNotIn("export.log", calls)
        self.assertFalse((self.output / "build-info.json").exists())


if __name__ == "__main__":
    unittest.main()
