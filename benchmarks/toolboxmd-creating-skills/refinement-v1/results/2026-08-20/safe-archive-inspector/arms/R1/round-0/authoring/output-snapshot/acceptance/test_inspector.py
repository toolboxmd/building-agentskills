#!/usr/bin/env python3
import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import stat
import sys
import tarfile
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "skills" / "safe-archive-inspector" / "scripts" / "inspect_archive.py"
SPEC = importlib.util.spec_from_file_location("inspector", HELPER)
INSPECTOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(INSPECTOR)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def invoke(path, entries=20, size=1000):
    before = digest(path)
    stdout = io.StringIO()
    stderr = io.StringIO()
    argv = ["--archive", str(path), "--max-entries", str(entries),
            "--max-total-bytes", str(size)]
    with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
        code = INSPECTOR.main(argv)
    output = stdout.getvalue()
    assert stderr.getvalue() == "", stderr.getvalue()
    assert output.endswith("\n") and output.count("\n") == 1
    assert digest(path) == before
    return code, json.loads(output)


def tar_add(archive, name, kind=tarfile.REGTYPE, size=0, linkname=""):
    info = tarfile.TarInfo(name)
    info.type = kind
    info.size = size
    info.linkname = linkname
    archive.addfile(info, io.BytesIO(b"x" * size) if size else None)


def zip_add(archive, name, data=b"", mode=None):
    info = zipfile.ZipInfo(name)
    if mode is not None:
        info.create_system = 3
        info.external_attr = mode << 16
    archive.writestr(info, data)


def main():
    with tempfile.TemporaryDirectory(dir=str(ROOT / "acceptance")) as tmp:
        base = Path(tmp)
        safe_tar = base / "safe.tar"
        with tarfile.open(safe_tar, "w") as archive:
            tar_add(archive, "folder", tarfile.DIRTYPE)
            tar_add(archive, "folder/file.txt", size=4)
        code, data = invoke(safe_tar)
        assert (code, data["status"], data["format"], data["declaredBytes"]) == (0, "safe", "tar", 4)

        bad_tar = base / "bad.tar"
        with tarfile.open(bad_tar, "w") as archive:
            tar_add(archive, "../escape")
            tar_add(archive, "Case")
            tar_add(archive, "case")
            tar_add(archive, "link", tarfile.SYMTYPE, linkname="target")
            tar_add(archive, "pipe", tarfile.FIFOTYPE)
        code, data = invoke(bad_tar, entries=2)
        assert code == 1
        assert {"PATH_PARENT", "PATH_CASE_COLLISION", "TYPE_LINK", "TYPE_SPECIAL", "ENTRY_LIMIT"} <= set(data["issues"])

        safe_zip = base / "safe.zip"
        with zipfile.ZipFile(safe_zip, "w") as archive:
            zip_add(archive, "folder/", mode=stat.S_IFDIR | 0o755)
            zip_add(archive, "folder/file.txt", b"abcd", stat.S_IFREG | 0o644)
        code, data = invoke(safe_zip)
        assert (code, data["status"], data["format"], data["declaredBytes"]) == (0, "safe", "zip", 4)

        bad_zip = base / "bad.zip"
        with zipfile.ZipFile(bad_zip, "w") as archive:
            with contextlib.redirect_stderr(io.StringIO()):
                zip_add(archive, "same", b"")
                zip_add(archive, "same", b"")
            zip_add(archive, "\\\\server\\share", b"")
            zip_add(archive, "sym", b"target", stat.S_IFLNK | 0o777)
        raw = bytearray(bad_zip.read_bytes())
        for signature, flag_offset in ((b"PK\x03\x04", 6), (b"PK\x01\x02", 8)):
            position = raw.find(signature)
            flags = int.from_bytes(raw[position + flag_offset:position + flag_offset + 2], "little")
            raw[position + flag_offset:position + flag_offset + 2] = (flags | 1).to_bytes(2, "little")
        bad_zip.write_bytes(raw)
        code, data = invoke(bad_zip, size=2)
        assert code == 1
        assert {"PATH_DUPLICATE", "PATH_ABSOLUTE", "TYPE_LINK", "ZIP_ENCRYPTED", "SIZE_LIMIT"} <= set(data["issues"])

        malformed = base / "broken.bin"
        malformed.write_bytes(b"not an archive")
        code, data = invoke(malformed)
        assert code == 2 and data["status"] == "error" and data["issues"] == ["ARCHIVE_INVALID"]

        # Prove the inspection functions do not call member-payload APIs.
        original_zip_open = zipfile.ZipFile.open
        original_extractfile = tarfile.TarFile.extractfile
        try:
            zipfile.ZipFile.open = lambda *args, **kwargs: (_ for _ in ()).throw(AssertionError("ZIP payload opened"))
            tarfile.TarFile.extractfile = lambda *args, **kwargs: (_ for _ in ()).throw(AssertionError("TAR payload opened"))
            assert INSPECTOR.inspect_zip(str(safe_zip), 20, 1000)[2] == set()
            assert INSPECTOR.inspect_tar(str(safe_tar), 20, 1000)[2] == set()
        finally:
            zipfile.ZipFile.open = original_zip_open
            tarfile.TarFile.extractfile = original_extractfile

    print("acceptance: 5 archive cases and payload-API guards passed")


if __name__ == "__main__":
    main()
