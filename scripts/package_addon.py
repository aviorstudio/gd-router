#!/usr/bin/env python3
"""Build and verify the exact release ZIP from a closed file manifest."""

from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path, PurePosixPath
import shutil
import stat
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "addon"
MANIFEST = ROOT / "packaging" / "addon-manifest.txt"
DEFAULT_ZIP = ROOT / "dist" / "@aviorstudio_gd-router.zip"


def declared_files() -> list[str]:
    entries = [line.strip() for line in MANIFEST.read_text().splitlines() if line.strip()]
    if entries != sorted(set(entries)):
        raise ValueError("addon manifest must be sorted and contain no duplicates")
    for entry in entries:
        path = PurePosixPath(entry)
        if path.is_absolute() or ".." in path.parts or str(path) != entry:
            raise ValueError(f"unsafe addon manifest entry: {entry}")
    return entries


def source_files() -> list[str]:
    files: list[str] = []
    for path in ADDON.rglob("*"):
        if path.is_symlink():
            raise ValueError(f"addon source contains a symlink: {path.relative_to(ADDON)}")
        if path.is_file():
            files.append(path.relative_to(ADDON).as_posix())
    return sorted(files)


def check_source(entries: list[str]) -> None:
    actual = source_files()
    if actual != entries:
        missing = sorted(set(entries) - set(actual))
        unexpected = sorted(set(actual) - set(entries))
        raise ValueError(f"closed manifest mismatch; missing={missing}; unexpected={unexpected}")


def build(output: Path, entries: list[str]) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for entry in entries:
            info = zipfile.ZipInfo(entry, date_time=(1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | 0o644) << 16
            archive.writestr(info, (ADDON / entry).read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)


def inspect_archive(archive_path: Path, entries: list[str]) -> None:
    with zipfile.ZipFile(archive_path) as archive:
        names: list[str] = []
        for info in archive.infolist():
            path = PurePosixPath(info.filename)
            mode = info.external_attr >> 16
            if info.is_dir() or path.is_absolute() or ".." in path.parts:
                raise ValueError(f"unsafe or undeclared archive entry: {info.filename}")
            if stat.S_ISLNK(mode):
                raise ValueError(f"archive contains a symlink: {info.filename}")
            if archive.read(info) != (ADDON / info.filename).read_bytes():
                raise ValueError(f"archive bytes differ from source: {info.filename}")
            names.append(info.filename)
        if names != entries:
            raise ValueError(f"archive manifest mismatch; actual={names}")


def tree_digest(archive_path: Path, entries: list[str]) -> str:
    digest = hashlib.sha256()
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        with zipfile.ZipFile(archive_path) as archive:
            archive.extractall(root)
        for entry in entries:
            digest.update(entry.encode())
            digest.update(b"\0")
            digest.update((root / entry).read_bytes())
            digest.update(b"\0")
    return digest.hexdigest()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_ZIP)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    entries = declared_files()
    check_source(entries)
    if not args.verify_only:
        build(output, entries)
    inspect_archive(output, entries)
    print(f"PACKAGE_ZIP={output}")
    print(f"PACKAGE_SHA256={sha256(output)}")
    print(f"INSTALLED_TREE_SHA256={tree_digest(output, entries)}")
    print(f"PACKAGE_FILE_COUNT={len(entries)}")


if __name__ == "__main__":
    main()
