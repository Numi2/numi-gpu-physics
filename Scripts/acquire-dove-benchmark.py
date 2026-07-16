#!/usr/bin/env python3
"""Verify and selectively acquire the qualified Deetjen dove benchmark.

The source is a 19.3 GB Zip64 archive. Zenodo supports HTTP byte ranges, so
this tool reads the central directory remotely and extracts only the members
locked in ValidationArtifacts/deetjen-dove-source-qualification.json.

By default it performs a read-only remote source verification. Downloads are
explicit and CRC-checked. The large SurfFits member is separately opt-in.
"""

from __future__ import annotations

import argparse
import binascii
import fcntl
import hashlib
import io
import json
from pathlib import Path
import shutil
import struct
import sys
import urllib.request
import zipfile
import zlib


DEFAULT_AUDIT = Path("ValidationArtifacts/deetjen-dove-source-qualification.json")
USER_AGENT = "BirdFlowMetal-source-qualification/1"
LOCAL_FILE_HEADER = struct.Struct("<IHHHHHIIIHH")
LOCAL_FILE_SIGNATURE = 0x04034B50
CHUNK_BYTES = 4 * 1024 * 1024


def fail(message: str) -> None:
    raise SystemExit(message)


def fetch(
    url: str,
    *,
    byte_range: tuple[int, int] | None = None,
    method: str = "GET",
):
    headers = {"User-Agent": USER_AGENT}
    if byte_range is not None:
        headers["Range"] = f"bytes={byte_range[0]}-{byte_range[1]}"
    request = urllib.request.Request(url, headers=headers, method=method)
    return urllib.request.urlopen(request, timeout=60)


def fetch_bytes(url: str) -> bytes:
    with fetch(url) as response:
        return response.read()


class HTTPRangeReader(io.RawIOBase):
    """Minimal seekable reader used only for the remote ZIP directory."""

    def __init__(self, url: str, size: int):
        self.url = url
        self.size = size
        self.position = 0

    def readable(self) -> bool:
        return True

    def seekable(self) -> bool:
        return True

    def tell(self) -> int:
        return self.position

    def seek(self, offset: int, whence: int = io.SEEK_SET) -> int:
        if whence == io.SEEK_SET:
            position = offset
        elif whence == io.SEEK_CUR:
            position = self.position + offset
        elif whence == io.SEEK_END:
            position = self.size + offset
        else:
            raise ValueError(f"unsupported seek mode {whence}")
        if position < 0:
            raise ValueError("negative seek position")
        self.position = position
        return position

    def read(self, size: int = -1) -> bytes:
        if self.position >= self.size:
            return b""
        if size is None or size < 0:
            end = self.size - 1
        else:
            end = min(self.position + size, self.size) - 1
        start = self.position
        with fetch(self.url, byte_range=(start, end)) as response:
            if response.status != 206:
                fail(
                    "remote ZIP server ignored a byte-range request; "
                    "refusing a possible 19.3 GB transfer"
                )
            data = response.read()
        expected = end - start + 1
        if len(data) != expected:
            fail(
                f"short remote ZIP read at {start}: "
                f"expected {expected}, received {len(data)}"
            )
        self.position = end + 1
        return data


def validate_internal_audit(audit: dict) -> list[dict]:
    if audit.get("schemaVersion") != 1:
        fail("unsupported dove source qualification schema")
    selected = audit.get("selectedBenchmark", {})
    members = selected.get("requiredArchiveMembers", [])
    if not members:
        fail("source qualification contains no required archive members")
    paths = [member.get("path") for member in members]
    if None in paths or len(paths) != len(set(paths)):
        fail("required archive member paths are missing or duplicated")

    code_members = audit.get("selectedBenchmark", {}).get(
        "forceRegistrationCodeMembers", []
    )
    if len(code_members) != 2:
        fail("force registration must lock exactly two deposited code members")
    code_paths = [member.get("path") for member in code_members]
    if (
        None in code_paths
        or len(code_paths) != len(set(code_paths))
        or set(paths).intersection(code_paths)
    ):
        fail("force-registration code paths are missing or duplicated")
    for member in code_members:
        if not all(
            member.get(key)
            for key in (
                "role",
                "evidenceClass",
                "bytes",
                "compressedBytes",
                "crc32",
                "sha256",
            )
        ):
            fail(f"incomplete force-registration code lock: {member.get('path')}")
        if len(member["sha256"]) != 64:
            fail(f"invalid code SHA-256 lock: {member['path']}")

    default_members = [member for member in members if member.get("includeByDefault")]
    expected_totals = {
        "defaultSubsetCompressedBytes": sum(
            member["compressedBytes"] for member in default_members
        ),
        "defaultSubsetUncompressedBytes": sum(
            member["bytes"] for member in default_members
        ),
        "surfaceSubsetCompressedBytes": sum(
            member["compressedBytes"] for member in members
        ),
        "surfaceSubsetUncompressedBytes": sum(member["bytes"] for member in members),
    }
    for key, actual in expected_totals.items():
        if selected.get(key) != actual:
            fail(f"{key} mismatch: audit={selected.get(key)!r}, member sum={actual}")

    disposition = audit.get("validationDisposition", {})
    if not disposition.get("sourceQualified"):
        fail("the source qualification must retain sourceQualified=true")
    if disposition.get("prescribedMotionExternalForceBenchmarkReady"):
        fail("the first CFD comparison has not been completed")
    if disposition.get("quantitativeBiologicalFreeFlightSchema2Ready"):
        fail("the dove source must not be promoted to measured schema 2")
    if not disposition.get("hybridFreeFlightAllowed"):
        fail("the explicit hybrid uncertainty route unexpectedly disappeared")

    force_rule = audit.get("measurementBoundary", {}).get("forceTruthRule", "")
    if "Only FxWings and FzWings" not in force_rule:
        fail("the measured-force claim boundary is missing")
    return members


def verify_remote(audit: dict, members: list[dict]):
    mirror = audit["sourceLocks"]["zenodoMirror"]
    record = json.loads(fetch_bytes(mirror["api"]))
    if record.get("id") != mirror["recordId"]:
        fail("Zenodo record identifier changed")
    if record.get("doi") != mirror["doi"]:
        fail("Zenodo DOI changed")
    license_id = record.get("metadata", {}).get("license", {}).get("id")
    if license_id != mirror["licenseIdentifier"]:
        fail(f"Zenodo license changed to {license_id!r}")

    remote_files = {entry["key"]: entry for entry in record.get("files", [])}
    for lock_name in ("archive", "readme"):
        lock = mirror[lock_name]
        remote = remote_files.get(lock["file"])
        if remote is None:
            fail(f"Zenodo file disappeared: {lock['file']}")
        if remote.get("size") != lock["bytes"]:
            fail(f"Zenodo file size changed: {lock['file']}")
        if remote.get("checksum") != f"md5:{lock['md5']}":
            fail(f"Zenodo checksum changed: {lock['file']}")

    readme_lock = mirror["readme"]
    readme_bytes = fetch_bytes(remote_files[readme_lock["file"]]["links"]["self"])
    if len(readme_bytes) != readme_lock["bytes"]:
        fail("README byte length changed")
    if hashlib.md5(readme_bytes).hexdigest() != readme_lock["md5"]:
        fail("README MD5 changed")
    if hashlib.sha256(readme_bytes).hexdigest() != readme_lock["sha256"]:
        fail("README SHA-256 changed")

    archive_lock = mirror["archive"]
    archive_url = remote_files[archive_lock["file"]]["links"]["self"]
    range_reader = HTTPRangeReader(archive_url, archive_lock["bytes"])
    with zipfile.ZipFile(range_reader) as archive:
        archive_infos = archive.infolist()
        if len(archive_infos) != audit["remoteArchiveInventory"]["entryCount"]:
            fail("remote ZIP entry count changed")
        info_by_name = {info.filename: info for info in archive_infos}
        selected_infos = {}
        for member in members:
            path = member["path"]
            info = info_by_name.get(path)
            if info is None:
                fail(f"qualified ZIP member disappeared: {path}")
            checks = {
                "bytes": info.file_size,
                "compressedBytes": info.compress_size,
                "crc32": f"{info.CRC:08x}",
            }
            for key, actual in checks.items():
                if member[key] != actual:
                    fail(
                        f"qualified ZIP member {key} changed for {path}: "
                        f"audit={member[key]!r}, remote={actual!r}"
                    )
            if info.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED):
                fail(f"unsupported compression type for {path}")
            selected_infos[path] = info
    return archive_url, selected_infos


def crc32_file(path: Path) -> tuple[int, int]:
    crc = 0
    size = 0
    with path.open("rb") as source:
        while True:
            chunk = source.read(CHUNK_BYTES)
            if not chunk:
                break
            size += len(chunk)
            crc = binascii.crc32(chunk, crc)
    return size, crc & 0xFFFFFFFF


def target_path(output: Path, archive_path: str) -> Path:
    relative = Path(archive_path)
    if relative.parts[0] != "DoveMuscles_DataCode" or ".." in relative.parts:
        fail(f"unsafe qualified archive path: {archive_path}")
    return output.joinpath(*relative.parts[1:])


def _extract_member_unlocked(
    archive_url: str,
    info: zipfile.ZipInfo,
    output: Path,
) -> tuple[Path, bool]:
    destination = target_path(output, info.filename)
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        size, crc = crc32_file(destination)
        if size == info.file_size and crc == info.CRC:
            return destination, False
        fail(f"existing file does not match source lock: {destination}")

    header_start = info.header_offset
    header_end = header_start + LOCAL_FILE_HEADER.size - 1
    with fetch(archive_url, byte_range=(header_start, header_end)) as response:
        if response.status != 206:
            fail("remote server ignored local-header range request")
        header = response.read()
    if len(header) != LOCAL_FILE_HEADER.size:
        fail(f"short local ZIP header for {info.filename}")
    fields = LOCAL_FILE_HEADER.unpack(header)
    signature = fields[0]
    flags = fields[2]
    filename_length = fields[9]
    extra_length = fields[10]
    if signature != LOCAL_FILE_SIGNATURE:
        fail(f"invalid local ZIP signature for {info.filename}")
    if flags & 0x1:
        fail(f"encrypted ZIP member is unsupported: {info.filename}")
    data_start = header_start + LOCAL_FILE_HEADER.size + filename_length + extra_length
    data_end = data_start + info.compress_size - 1

    temporary = destination.with_name(destination.name + ".part")
    if temporary.exists():
        temporary.unlink()
    decompressor = None
    if info.compress_type == zipfile.ZIP_DEFLATED:
        decompressor = zlib.decompressobj(-zlib.MAX_WBITS)
    elif info.compress_type != zipfile.ZIP_STORED:
        fail(f"unsupported compression type for {info.filename}")

    compressed_read = 0
    uncompressed_written = 0
    crc = 0
    try:
        with fetch(archive_url, byte_range=(data_start, data_end)) as response:
            if response.status != 206:
                fail("remote server ignored member range request")
            with temporary.open("wb") as target:
                while True:
                    chunk = response.read(CHUNK_BYTES)
                    if not chunk:
                        break
                    compressed_read += len(chunk)
                    output_chunk = (
                        decompressor.decompress(chunk)
                        if decompressor is not None
                        else chunk
                    )
                    if output_chunk:
                        target.write(output_chunk)
                        uncompressed_written += len(output_chunk)
                        crc = binascii.crc32(output_chunk, crc)
                if decompressor is not None:
                    output_chunk = decompressor.flush()
                    if output_chunk:
                        target.write(output_chunk)
                        uncompressed_written += len(output_chunk)
                        crc = binascii.crc32(output_chunk, crc)
        if compressed_read != info.compress_size:
            fail(
                f"compressed byte count mismatch for {info.filename}: "
                f"{compressed_read} != {info.compress_size}"
            )
        if uncompressed_written != info.file_size:
            fail(
                f"uncompressed byte count mismatch for {info.filename}: "
                f"{uncompressed_written} != {info.file_size}"
            )
        if (crc & 0xFFFFFFFF) != info.CRC:
            fail(f"CRC mismatch after extracting {info.filename}")
        temporary.replace(destination)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise
    return destination, True


def extract_member(
    archive_url: str,
    info: zipfile.ZipInfo,
    output: Path,
) -> tuple[Path, bool]:
    destination = target_path(output, info.filename)
    destination.parent.mkdir(parents=True, exist_ok=True)
    lock_path = destination.with_name(destination.name + ".lock")
    with lock_path.open("a+b") as lock_file:
        try:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            fail(f"another extraction is active for {destination}")
        try:
            return _extract_member_unlocked(archive_url, info, output)
        finally:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
            lock_path.unlink(missing_ok=True)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Verify the qualified Deetjen dove source and selectively acquire "
            "one synchronized flight"
        )
    )
    parser.add_argument("--audit", type=Path, default=DEFAULT_AUDIT)
    parser.add_argument(
        "--offline",
        action="store_true",
        help="validate only the committed audit and claim boundary",
    )
    parser.add_argument(
        "--download",
        action="store_true",
        help="extract the default approximately 15 MB engineering subset",
    )
    parser.add_argument(
        "--include-surface",
        action="store_true",
        help="also extract the approximately 656 MB compressed SurfFits member",
    )
    parser.add_argument(
        "--include-force-code",
        action="store_true",
        help=(
            "also extract the two small deposited scripts that establish "
            "force sign, axes, and timing"
        ),
    )
    parser.add_argument("--output", type=Path)
    parser.add_argument("--json", action="store_true")
    arguments = parser.parse_args()
    if arguments.download and arguments.output is None:
        fail("--download requires --output")
    if arguments.include_surface and not arguments.download:
        fail("--include-surface requires --download")
    if arguments.include_force_code and not arguments.download:
        fail("--include-force-code requires --download")
    if arguments.offline and arguments.download:
        fail("--offline cannot be combined with --download")

    audit = json.loads(arguments.audit.read_bytes())
    members = validate_internal_audit(audit)
    code_members = audit["selectedBenchmark"]["forceRegistrationCodeMembers"]
    archive_url = None
    infos = None
    if not arguments.offline:
        archive_url, infos = verify_remote(audit, members + code_members)

    chosen = [member for member in members if member["includeByDefault"]]
    if arguments.include_surface:
        chosen = members
    if arguments.include_force_code:
        chosen += code_members
    downloaded = []
    reused = []
    if arguments.download:
        assert archive_url is not None and infos is not None
        arguments.output.mkdir(parents=True, exist_ok=True)
        needed = sum(member["bytes"] for member in chosen)
        available = shutil.disk_usage(arguments.output).free
        if available < needed + 64 * 1024 * 1024:
            fail(
                f"insufficient free space: need at least {needed} bytes plus "
                "64 MiB safety margin"
            )
        for member in chosen:
            print(f"acquiring {member['path']}", file=sys.stderr)
            destination, created = extract_member(
                archive_url,
                infos[member["path"]],
                arguments.output,
            )
            (downloaded if created else reused).append(str(destination))

    result = {
        "auditIdentifier": audit["auditIdentifier"],
        "selectedFlight": audit["selectedBenchmark"]["flightIdentifier"],
        "internalAuditPassed": True,
        "remoteSourcePassed": None if arguments.offline else True,
        "remoteZipEntryCount": (
            None if arguments.offline else audit["remoteArchiveInventory"]["entryCount"]
        ),
        "selectedMemberCount": len(chosen),
        "selectedCompressedBytes": sum(member["compressedBytes"] for member in chosen),
        "selectedUncompressedBytes": sum(member["bytes"] for member in chosen),
        "surfaceIncluded": arguments.include_surface,
        "forceRegistrationCodeIncluded": arguments.include_force_code,
        "downloaded": downloaded,
        "reused": reused,
        "measuredForceTargets": ["FxWings", "FzWings"],
        "measuredSchema2Ready": False,
    }
    if arguments.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        mode = "offline audit" if arguments.offline else "remote source"
        print(f"PASS: {mode} qualification")
        print(f"selected flight: {result['selectedFlight']}")
        print(
            f"selected transfer: {result['selectedCompressedBytes']} compressed bytes"
        )
        if arguments.download:
            print(f"downloaded: {len(downloaded)}; reused: {len(reused)}")


if __name__ == "__main__":
    main()
