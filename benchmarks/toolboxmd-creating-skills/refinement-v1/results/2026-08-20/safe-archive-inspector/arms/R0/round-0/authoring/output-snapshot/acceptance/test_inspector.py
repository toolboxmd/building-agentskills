#!/usr/bin/env python3
import io
import contextlib
import importlib.util
import json
import os
import pathlib
import stat
import sys
import tarfile
import zipfile


ROOT = pathlib.Path(__file__).resolve().parents[2]
HELPER = ROOT / "output/skills/safe-archive-inspector/scripts/inspect_archive.py"
FIXTURES = ROOT / "output/acceptance/fixtures"
FIXTURES.mkdir(parents=True, exist_ok=True)
SPEC = importlib.util.spec_from_file_location("inspect_archive", HELPER)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def run(path, entries=20, size=10000, extra=()):
    argv = ["--archive", str(path), "--max-entries", str(entries),
            "--max-total-bytes", str(size)]
    argv.extend(extra)
    stdout = io.StringIO()
    stderr = io.StringIO()
    with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
        code = MODULE.main(argv)
    output = stdout.getvalue()
    assert stderr.getvalue() == "", stderr.getvalue()
    assert output.endswith("\n") and output.count("\n") == 1
    return code, json.loads(output)


def expect(path, exit_code, status, issues=(), entries=20, size=10000):
    code, result = run(path, entries, size)
    assert code == exit_code, (path, code, result)
    assert result["schemaVersion"] == 1
    assert result["status"] == status
    assert set(issues).issubset(result["issues"]), (path, result)
    assert list(result) == ["schemaVersion", "status", "format", "entryCount",
                            "declaredBytes", "issues"]
    return result


safe_zip = FIXTURES / "safe.zip"
with zipfile.ZipFile(safe_zip, "w", zipfile.ZIP_DEFLATED) as archive:
    archive.writestr("docs/", b"")
    archive.writestr("docs/readme.txt", b"SECRET")
expect(safe_zip, 0, "safe")
expect(safe_zip, 1, "unsafe", ["ENTRY_LIMIT"], entries=1)
expect(safe_zip, 1, "unsafe", ["SIZE_LIMIT"], size=5)

# Corrupt the compressed payload. Metadata inspection remains safe; member.read()
# would fail, so this exercises the no-payload-read boundary.
corrupt_payload_zip = FIXTURES / "corrupt-payload.zip"
with zipfile.ZipFile(corrupt_payload_zip, "w", zipfile.ZIP_STORED) as archive:
    archive.writestr("payload.txt", b"SECRET")
data = bytearray(corrupt_payload_zip.read_bytes())
marker = data.find(b"SECRET")
assert marker >= 0
data[marker] ^= 0x01
corrupt_payload_zip.write_bytes(data)
expect(corrupt_payload_zip, 0, "safe")

paths_zip = FIXTURES / "paths.zip"
with zipfile.ZipFile(paths_zip, "w") as archive:
    archive.writestr("../escape", b"x")
    archive.writestr("C:\\escape", b"x")
    archive.writestr("A/./b", b"x")
    archive.writestr("a/b", b"x")
    archive.writestr("bad\x01name", b"x")
result = expect(paths_zip, 1, "unsafe",
                ["PATH_PARENT", "PATH_ABSOLUTE", "PATH_CASE_COLLISION",
                 "PATH_CONTROL"])
assert result["entryCount"] == 5 and result["declaredBytes"] == 5

duplicate_zip = FIXTURES / "duplicate.zip"
with zipfile.ZipFile(duplicate_zip, "w") as archive:
    archive.writestr("same", b"1")
    archive.writestr("same", b"2")
expect(duplicate_zip, 1, "unsafe", ["PATH_DUPLICATE"])

special_zip = FIXTURES / "special.zip"
with zipfile.ZipFile(special_zip, "w") as archive:
    link = zipfile.ZipInfo("link")
    link.create_system = 3
    link.external_attr = (stat.S_IFLNK | 0o777) << 16
    archive.writestr(link, b"target")
    fifo = zipfile.ZipInfo("fifo")
    fifo.create_system = 3
    fifo.external_attr = (stat.S_IFIFO | 0o600) << 16
    archive.writestr(fifo, b"")
expect(special_zip, 1, "unsafe", ["TYPE_LINK", "TYPE_SPECIAL"])

encrypted_zip = FIXTURES / "encrypted-flag.zip"
with zipfile.ZipFile(encrypted_zip, "w") as archive:
    archive.writestr("flagged", b"data")
data = bytearray(encrypted_zip.read_bytes())
for signature, offset in ((b"PK\x03\x04", 6), (b"PK\x01\x02", 8)):
    position = data.find(signature)
    flags = int.from_bytes(data[position + offset:position + offset + 2], "little") | 1
    data[position + offset:position + offset + 2] = flags.to_bytes(2, "little")
encrypted_zip.write_bytes(data)
expect(encrypted_zip, 1, "unsafe", ["ZIP_ENCRYPTED"])

safe_tar = FIXTURES / "safe.tar"
with tarfile.open(safe_tar, "w") as archive:
    directory = tarfile.TarInfo("docs")
    directory.type = tarfile.DIRTYPE
    archive.addfile(directory)
    regular = tarfile.TarInfo("docs/readme.txt")
    regular.size = 6
    archive.addfile(regular, io.BytesIO(b"SECRET"))
expect(safe_tar, 0, "safe")

unsafe_tar = FIXTURES / "unsafe.tar"
with tarfile.open(unsafe_tar, "w") as archive:
    parent = tarfile.TarInfo("a\\..\\escape")
    parent.size = 0
    archive.addfile(parent, io.BytesIO())
    link = tarfile.TarInfo("link")
    link.type = tarfile.SYMTYPE
    link.linkname = "target"
    archive.addfile(link)
    fifo = tarfile.TarInfo("fifo")
    fifo.type = tarfile.FIFOTYPE
    archive.addfile(fifo)
expect(unsafe_tar, 1, "unsafe", ["PATH_PARENT", "TYPE_LINK", "TYPE_SPECIAL"])

malformed = FIXTURES / "malformed.bin"
malformed.write_bytes(b"not an archive")
expect(malformed, 2, "error", ["ARCHIVE_INVALID"])

code, result = run(safe_zip, extra=("--unknown",))
assert code == 2 and result["status"] == "error" and result["issues"] == ["INPUT"]

# Determinism check.
assert run(unsafe_tar) == run(unsafe_tar)
print("PASS", sys.version.split()[0], "representative TAR/ZIP acceptance cases")
