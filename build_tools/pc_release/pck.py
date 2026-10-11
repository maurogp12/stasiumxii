"""Read and write Godot 4 PCK files (pack format 3 and 4).

Layout (little endian), as written by Godot 4.7:
  "GDPC", pack_version u32, engine major/minor/patch u32, pack_flags u32,
  file_base u64, dir_offset u64 (format >= 3), reserved u32 x 16, padding,
  file data..., directory at dir_offset:
  count u32, then per file: path_len u32 (padded to 4), path (no "res://"),
  offset u64 (relative to file_base when PACK_REL_FILEBASE), size u64,
  md5[16], flags u32.

Entry flags: 1 = encrypted, 2 = removal (a patch deletes the path).
"""

from __future__ import annotations

import hashlib
import struct
from dataclasses import dataclass

MAGIC = b"GDPC"
PACK_DIR_ENCRYPTED = 1
PACK_REL_FILEBASE = 2
FILE_ENCRYPTED = 1
FILE_REMOVAL = 2
ALIGN = 16


@dataclass
class Entry:
    path: str
    offset: int  # absolute offset in the pack file
    size: int
    md5: str
    flags: int

    @property
    def removal(self) -> bool:
        return bool(self.flags & FILE_REMOVAL)


@dataclass
class Pack:
    path: str
    version: int
    engine: tuple
    flags: int
    entries: list

    def by_path(self) -> dict:
        return {e.path: e for e in self.entries}


def read_pack(path: str) -> Pack:
    with open(path, "rb") as f:
        head = f.read(40)
        magic, ver, major, minor, patch, pflags = struct.unpack_from("<4sIIIII", head, 0)
        if magic != MAGIC:
            raise ValueError(f"{path}: not a PCK")
        if ver < 3:
            raise ValueError(f"{path}: pack format {ver} is too old")
        if pflags & PACK_DIR_ENCRYPTED:
            raise ValueError(f"{path}: encrypted directory not supported")
        file_base, dir_off = struct.unpack_from("<QQ", head, 24)
        f.seek(dir_off)
        (count,) = struct.unpack("<I", f.read(4))
        entries = []
        for _ in range(count):
            (plen,) = struct.unpack("<I", f.read(4))
            p = f.read(plen).rstrip(b"\0").decode("utf-8")
            off, size = struct.unpack("<QQ", f.read(16))
            md5 = f.read(16).hex()
            (fl,) = struct.unpack("<I", f.read(4))
            if pflags & PACK_REL_FILEBASE:
                off += file_base
            entries.append(Entry(p, off, size, md5, fl))
    return Pack(path, ver, (major, minor, patch), pflags, entries)


def iter_data(pack_path: str, entry: Entry, block: int = 1 << 20):
    with open(pack_path, "rb") as f:
        f.seek(entry.offset)
        left = entry.size
        while left > 0:
            b = f.read(min(block, left))
            if not b:
                raise IOError(f"{pack_path}: short read for {entry.path}")
            left -= len(b)
            yield b


def write_pack(dst: str, version: int, engine: tuple, items: list) -> int:
    """items: list of (path, source) where source is None for a removal,
    or (pack_path, Entry) to copy bytes from an existing pack.
    Returns the written size."""
    header_size = 40 + 16 * 4
    file_base = (header_size + ALIGN - 1) // ALIGN * ALIGN
    dir_rows = []
    with open(dst, "wb") as out:
        out.write(b"\0" * file_base)
        pos = 0
        for path, src in sorted(items, key=lambda x: x[0]):
            if src is None:
                dir_rows.append((path, 0, 0, b"\0" * 16, FILE_REMOVAL))
                continue
            pack_path, e = src
            md5 = hashlib.md5()
            for b in iter_data(pack_path, e):
                out.write(b)
                md5.update(b)
            if md5.hexdigest() != e.md5:
                raise ValueError(f"md5 mismatch copying {path}")
            dir_rows.append((path, pos, e.size, md5.digest(), e.flags & ~FILE_REMOVAL))
            pos += e.size
            pad = (-pos) % ALIGN
            out.write(b"\0" * pad)
            pos += pad
        dir_off = file_base + pos
        out.write(struct.pack("<I", len(dir_rows)))
        for path, off, size, md5, fl in dir_rows:
            raw = path.encode("utf-8")
            raw += b"\0" * ((-len(raw)) % 4)  # padded to 4, like Godot
            out.write(struct.pack("<I", len(raw)))
            out.write(raw)
            out.write(struct.pack("<QQ", off, size))
            out.write(md5)
            out.write(struct.pack("<I", fl))
        end = out.tell()
        out.seek(0)
        out.write(MAGIC)
        out.write(struct.pack("<IIIII", version, engine[0], engine[1], engine[2], PACK_REL_FILEBASE))
        out.write(struct.pack("<QQ", file_base, dir_off))
    return end


def file_state(pack: Pack) -> dict:
    """{path: [md5, size]} for the live files of one pack (removals skipped)."""
    return {e.path: [e.md5, e.size] for e in pack.entries if not e.removal}


def apply_patch_state(state: dict, patch: Pack) -> dict:
    out = dict(state)
    for e in patch.entries:
        if e.removal:
            out.pop(e.path, None)
        else:
            out[e.path] = [e.md5, e.size]
    return out


def diff_states(old: dict, new: dict):
    """Returns (changed_or_added, removed) path lists."""
    changed = sorted(p for p, v in new.items() if old.get(p) != v)
    removed = sorted(p for p in old if p not in new)
    return changed, removed


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()
