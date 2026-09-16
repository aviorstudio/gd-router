#!/usr/bin/env python3
"""Disposable source and installed-tree controls; never mutate the checkout."""

import importlib.util
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("package_addon", ROOT / "scripts/package_addon.py")
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)


class PackageContractTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for directory in ("addon", "packaging", "scripts"):
            shutil.copytree(ROOT / directory, self.root / directory)
        self.archive = self.root / "package.zip"

    def build(self, succeeds=True):
        result = subprocess.run(
            [sys.executable, str(self.root / "scripts/package_addon.py"), "--output", str(self.archive)],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode == 0, succeeds, result.stdout + result.stderr)
        return result.stdout + result.stderr

    def test_reproducible_known_good(self):
        self.build()
        first = self.archive.read_bytes()
        self.build()
        self.assertEqual(first, self.archive.read_bytes())

    def test_missing_uid_from_source_and_manifest_fails_then_restores(self):
        relative = "src/core/route_result.gd.uid"
        sidecar = self.root / "addon" / relative
        original = sidecar.read_bytes()
        manifest = self.root / "packaging/addon-manifest.txt"
        declared = manifest.read_text()
        sidecar.unlink()
        manifest.write_text(declared.replace(relative + "\n", ""))
        self.assertIn("missing shipped script UID", self.build(False))
        sidecar.write_bytes(original)
        manifest.write_text(declared)
        self.build()

    def test_malformed_uid_fails(self):
        (self.root / "addon/src/core/route_result.gd.uid").write_text("not a UID\n")
        self.assertIn("invalid shipped script UID", self.build(False))

    def test_manifest_only_uid_removal_fails(self):
        manifest = self.root / "packaging/addon-manifest.txt"
        manifest.write_text(manifest.read_text().replace("src/core/route_result.gd.uid\n", ""))
        self.assertIn("closed manifest mismatch", self.build(False))

    def test_source_only_uid_removal_fails(self):
        (self.root / "addon/src/core/route_result.gd.uid").unlink()
        self.assertIn("closed manifest mismatch", self.build(False))

    def test_duplicate_uid_fails(self):
        shutil.copyfile(self.root / "addon/autoload.gd.uid", self.root / "addon/src/core/route_result.gd.uid")
        self.assertIn("duplicate shipped script UID", self.build(False))

    def test_undeclared_uid_fails(self):
        (self.root / "addon/extra.gd.uid").write_text("uid://extra\n")
        self.assertIn("closed manifest mismatch", self.build(False))

    def test_complete_installed_tree_controls(self):
        self.build()
        installed = self.root / "installed"
        with zipfile.ZipFile(self.archive) as archive:
            archive.extractall(installed)
        package.inspect_install(self.archive, installed)
        for relative, extra_name in (
            ("src/core/route_result.gd.uid", "generated.gd.uid"),
            ("plugin.cfg", "unexpected.cfg"),
        ):
            target = installed / relative
            original = target.read_bytes()
            for mutation in ("missing", "changed", "unexpected"):
                with self.subTest(path=relative, mutation=mutation):
                    extra = installed / extra_name
                    if mutation == "missing":
                        target.unlink()
                    elif mutation == "changed":
                        target.write_bytes(original + b"mutated\n")
                    else:
                        extra.write_text("unexpected\n")
                    with self.assertRaisesRegex(ValueError, "installed addon differs"):
                        package.inspect_install(self.archive, installed)
                    target.write_bytes(original)
                    extra.unlink(missing_ok=True)
                    package.inspect_install(self.archive, installed)

    def test_archive_path_and_byte_controls(self):
        self.build()
        original = self.archive.read_bytes()
        with zipfile.ZipFile(self.archive) as archive:
            files = [(info, archive.read(info)) for info in archive.infolist()]
        for mutation in ("missing", "changed", "unexpected"):
            with self.subTest(mutation=mutation):
                with zipfile.ZipFile(self.archive, "w") as archive:
                    for info, content in files:
                        if info.filename == "plugin.cfg":
                            if mutation == "missing":
                                continue
                            if mutation == "changed":
                                content += b"mutated\n"
                        archive.writestr(info, content)
                    if mutation == "unexpected":
                        archive.writestr("unexpected.cfg", b"unexpected\n")
                result = subprocess.run(
                    [sys.executable, str(self.root / "scripts/package_addon.py"),
                     "--output", str(self.archive), "--verify-only"],
                    capture_output=True, text=True,
                )
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.archive.write_bytes(original)
                subprocess.run(
                    [sys.executable, str(self.root / "scripts/package_addon.py"),
                     "--output", str(self.archive), "--verify-only"],
                    capture_output=True, text=True, check=True,
                )


if __name__ == "__main__":
    unittest.main()
