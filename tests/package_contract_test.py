#!/usr/bin/env python3
"""Disposable source and installed-tree controls; never mutate the checkout."""

import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("package_addon", Path(os.environ["TOOLS_ROOT"]) / "helpers/addon-package.py")
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)


class PackageContractTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copytree(ROOT / "addon", self.root / "addon")
        shutil.copyfile(ROOT / "package-manifest.txt", self.root / "package-manifest.txt")
        self.archive = self.root / "package.zip"

    def build(self, succeeds=True):
        try:
            package.build(self.root / "addon", self.root / "package-manifest.txt", self.archive, script_uids=True)
        except ValueError as error:
            self.assertFalse(succeeds, str(error))
            return str(error)
        self.assertTrue(succeeds, "package mutation unexpectedly passed")
        return ""

    def test_reproducible_known_good(self):
        self.build()
        first = self.archive.read_bytes()
        self.build()
        self.assertEqual(first, self.archive.read_bytes())

    def test_missing_uid_from_source_and_manifest_fails_then_restores(self):
        relative = "src/core/route_result.gd.uid"
        sidecar = self.root / "addon" / relative
        original = sidecar.read_bytes()
        manifest = self.root / "package-manifest.txt"
        declared = manifest.read_text()
        sidecar.unlink()
        manifest.write_text(declared.replace(relative + "\n", ""))
        self.assertIn("GDScript requires a UID sidecar", self.build(False))
        sidecar.write_bytes(original)
        manifest.write_text(declared)
        self.build()

    def test_malformed_uid_fails(self):
        (self.root / "addon/src/core/route_result.gd.uid").write_text("not a UID\n")
        self.assertIn("script UIDs must be valid and unique", self.build(False))

    def test_manifest_only_uid_removal_fails(self):
        manifest = self.root / "package-manifest.txt"
        manifest.write_text(manifest.read_text().replace("src/core/route_result.gd.uid\n", ""))
        self.assertIn("source differs from the closed manifest", self.build(False))

    def test_source_only_uid_removal_fails(self):
        (self.root / "addon/src/core/route_result.gd.uid").unlink()
        self.assertIn("source differs from the closed manifest", self.build(False))

    def test_duplicate_uid_fails(self):
        shutil.copyfile(self.root / "addon/autoload.gd.uid", self.root / "addon/src/core/route_result.gd.uid")
        self.assertIn("script UIDs must be valid and unique", self.build(False))

    def test_undeclared_uid_fails(self):
        (self.root / "addon/extra.gd.uid").write_text("uid://extra\n")
        self.assertIn("source differs from the closed manifest", self.build(False))

    def test_complete_installed_tree_controls(self):
        self.build()
        installed = self.root / "installed"
        with zipfile.ZipFile(self.archive) as archive:
            archive.extractall(installed)
        package.verify(self.archive, self.root / "package-manifest.txt", source=self.root / "addon", installed=installed, script_uids=True)
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
                    with self.assertRaises(ValueError):
                        package.verify(self.archive, self.root / "package-manifest.txt", source=self.root / "addon", installed=installed, script_uids=True)
                    target.write_bytes(original)
                    extra.unlink(missing_ok=True)
                    package.verify(self.archive, self.root / "package-manifest.txt", source=self.root / "addon", installed=installed, script_uids=True)

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
                with self.assertRaises(ValueError):
                    package.verify(self.archive, self.root / "package-manifest.txt", source=self.root / "addon", script_uids=True)
                self.archive.write_bytes(original)
                package.verify(self.archive, self.root / "package-manifest.txt", source=self.root / "addon", script_uids=True)


if __name__ == "__main__":
    unittest.main()
