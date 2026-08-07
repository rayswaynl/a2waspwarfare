#!/usr/bin/env python3
"""BIS "Cprs" LZSS codec for Arma-family `.pbo` archives.

Provenance
----------
The BI wiki page describing this format (`Compressed_LZSS_File_Format`) is
behind a bot-check that this environment could not clear (CAPTCHA - out of
bounds per policy), and no `.pbo` file found on this machine (111 files
under this repo's own trees, 129 files across the real, Steam-installed
Arma 2: OA base game content, 413 files across 6 real third-party addon
folders installed alongside it) actually contains a single `mimetype != 0`
entry - every one of them, official BI content included, was packed fully
uncompressed. So this module is NOT reverse-engineered from a real
compressed sample on this machine; it is a direct, field-by-field port of
`BIS.Core.Compression.LZSS.ReadLZSS` from Braini01/bis-file-formats
(https://github.com/Braini01/bis-file-formats, MIT), a third-party .NET
library purpose-built to read real ArmA/BIS file formats (config.bin, PAA,
P3D, PBO, ...). That repo's own PBO reader (`BinaryReaderEx.ReadLZSS`,
called from `BIS.PBO/PBO.cs`) is wired to this exact function - and,
tellingly, an alternate decoder the same author tried first (a generic,
textbook Okumura-style absolute-position LZSS, `LzssStream` in
`LzssCompression.cs`) is left commented out at the PBO call site under an
"XXX: Needs testing" note, i.e. the author found the textbook form did NOT
correctly read real files and swapped in the implementation ported here
instead. That is about as strong a signal as is available without a boot
test that THIS is the byte-exact real algorithm, not merely "a" LZSS.

The two field-level facts this repo needed are also confirmed from that
same source, independent of the compression algorithm itself:
  - `FileEntry.CompressionMagic = BitConverter.ToInt32(ASCII("srpC"), 0)`
    i.e. the real on-disk mimetype bytes for a compressed entry spell
    "srpC", which as a little-endian uint32 is 0x43707273 - exactly the
    same encoding convention this project's own `pack_pbo.py` already uses
    for `MAGIC_VERS = 0x56657273` (confirmed against a real, Steam-installed
    `Common/weapons.pbo`: its on-disk header bytes are literally `sreV`).
    See `MAGIC_CPRS` below.
  - The real PBO reader (`BinaryReaderEx.ReadLZSS`, `inPAA=False`) never
    actually runs LZSS for an entry whose original size is < 1024 bytes -
    it reads that many raw bytes instead, even if the entry is tagged
    compressed. The matching writer has the identical `bytes.Length < 1024`
    guard. This module does NOT bake that threshold into `compress()` /
    `decompress()` (they are unconditional codec primitives, matching the
    task's requested signature) - any future PBO-entry-level integration
    (packer or reader) MUST apply that <1024 "never actually compressed"
    rule itself, or it will silently desync from a real engine. `read_pbo.py`
    applies it; see its `extract_entry_data()`.

Algorithm
---------
Classic Haruhiko Okumura `lzss.c` framing (ring buffer, space pre-fill,
4-bit-length/12-bit-distance match token, `0xff00` flag-refill trick), but
with BIS's own DISTANCE-relative (not absolute-position) match addressing -
this is the detail that differs from the generic textbook port and that the
real engine actually expects, per the provenance note above:

  - N = 4096  (ring buffer / window size, exactly the 12-bit distance field)
  - F = 18    (max match length)
  - THRESHOLD = 2  (only worth encoding as a match if length > THRESHOLD,
    i.e. length >= 3)
  - `text_buf[0 : N-F]` (4078 bytes) is pre-filled with ASCII space (0x20)
    before any real output exists. The ring write cursor `r` STARTS at
    `N-F`, i.e. right where the pre-fill ends and only 18 slots remain
    before the ring wraps back to index 0 and starts overwriting the
    pre-fill from the front. This is the "space-fill behaviour for offsets
    pointing before the start of output": a match's distance can legally
    resolve into the still-space-filled region (harmlessly emitting
    spaces) for roughly the first ~4078 bytes of a file's *true* output
    stream, before the ring has fully cycled once.
  - Flag byte: one bit per following item, LSB (bit 0) consumed first, via
    the `flags = (flags >> 1); if not (flags & 256): flags = next_byte |
    0xff00` refill idiom. Bit == 1 -> literal byte follows. Bit == 0 ->
    2-byte match token follows.
  - Match token (2 bytes `b1, b2`): `distance = b1 | ((b2 & 0xf0) << 4)`
    (12 bits, 0..4095) is how many ring-buffer slots BACK from the current
    write cursor `r` to start copying from (source = `(r - distance) &
    (N-1)`) - a true LZ77 relative offset, not an absolute ring index.
    `length = (b2 & 0x0f) + THRESHOLD + 1` (range 3..18, since the decode
    loop is inclusive of both endpoints: `THRESHOLD` is added to the 4-bit
    code and the copy loop then runs one further beyond that).
  - Trailing checksum: 4 bytes, little-endian, unsigned 32-bit wraparound
    sum of every DECOMPRESSED byte (0..255 each) - "additive spillover", not
    a real hash. PBO entries use the unsigned form (`inPAA=False`); PAA
    textures use a signed (sbyte) sum instead, which is out of scope here.

`compress()` here does NOT try to reproduce BIS's own (unverified, and per
the provenance note likely non-real-format) encoder. It is a fresh,
straightforward greedy LZ77 encoder (hash-chain match finder, bounded chain
depth) that targets this exact decode contract: same N/F/THRESHOLD, same
distance-relative addressing, same flag framing, same checksum. It never
emits a match that would reference the synthetic space pre-fill region
(only matches against real preceding input bytes are considered) - a
deliberate, always-safe simplification that costs at most a handful of
literal bytes of ratio at the very start of a file in the rare case it
begins with a long run of literal spaces.
"""

from __future__ import annotations

N = 4096  # ring buffer / window size
F = 18  # max match length
THRESHOLD = 2  # only encode as a match if length > THRESHOLD (i.e. >= 3)
MIN_MATCH = THRESHOLD + 1  # 3
MAX_MATCH = F  # 18

MAGIC_CPRS = 0x43707273  # ASCII "Cprs" written the way MAGIC_VERS already is
# in pack_pbo.py: struct.pack("<I", MAGIC_CPRS) == b"srpC", matching the
# real on-disk bytes confirmed against Common\weapons.pbo's own MAGIC_VERS.

_MAX_CHAIN = 64  # bounded hash-chain search depth; correctness-neutral,
# only trades compression ratio for encoder speed.


class CprsError(RuntimeError):
    """Raised for malformed compressed input or a checksum mismatch."""


def _checksum(data: bytes) -> int:
    """Unsigned 32-bit wraparound sum of every byte (PBO / non-PAA form)."""
    return sum(data) & 0xFFFFFFFF


def compress(data: bytes) -> bytes:
    """Compress `data` with the BIS Cprs LZSS scheme (see module docstring).

    Always produces a valid compressed stream, even for 0/1/2-byte inputs
    (with no possible match, it degrades to all-literal encoding, which is
    always larger than the input due to flag-byte overhead - callers that
    care about that tradeoff must decide separately whether to bother
    compressing a given entry; this function does not gate on size)."""
    n = len(data)
    out = bytearray()

    pending_flag = 0
    pending_bits = 0
    pending_payload = bytearray()

    def flush_group() -> None:
        nonlocal pending_flag, pending_bits, pending_payload
        if pending_bits > 0:
            out.append(pending_flag)
            out.extend(pending_payload)
            pending_flag = 0
            pending_bits = 0
            pending_payload = bytearray()

    def emit_literal(byte_val: int) -> None:
        nonlocal pending_flag, pending_bits
        pending_flag |= 1 << pending_bits
        pending_payload.append(byte_val)
        pending_bits += 1
        if pending_bits == 8:
            flush_group()

    def emit_match(distance: int, length: int) -> None:
        nonlocal pending_bits
        assert 1 <= distance <= N - 1
        assert MIN_MATCH <= length <= MAX_MATCH
        code = length - THRESHOLD - 1  # 0..15
        b1 = distance & 0xFF
        b2 = ((distance >> 4) & 0xF0) | code
        pending_payload.append(b1)
        pending_payload.append(b2)
        pending_bits += 1
        if pending_bits == 8:
            flush_group()

    # Greedy hash-chain LZ77 match finder over the raw input, keyed on
    # 3-byte prefixes. `prev[idx]` chains to the previous occurrence of the
    # same 3-byte key (or -1). Distances are `idx - candidate`, which is
    # exactly the ring-buffer distance a real decoder would need (see
    # module docstring for the derivation): the ring write position for
    # real-data index k is `(N - F + k) & (N - 1)`, so the distance between
    # writing index `cand` and index `idx` is `(idx - cand) & (N - 1)`,
    # which for `1 <= idx - cand <= N - 1` is simply `idx - cand` itself.
    head: dict[bytes, int] = {}
    prev = [-1] * n

    idx = 0
    while idx < n:
        best_len = 0
        best_dist = 0
        max_len = min(MAX_MATCH, n - idx)
        if max_len >= MIN_MATCH:
            key = bytes(data[idx : idx + 3])
            cand = head.get(key, -1)
            depth = 0
            while cand != -1 and depth < _MAX_CHAIN:
                dist = idx - cand
                if dist > N - 1:
                    break  # chain walks strictly backward -> only gets farther
                mlen = 0
                while mlen < max_len and data[cand + mlen] == data[idx + mlen]:
                    mlen += 1
                if mlen > best_len:
                    best_len = mlen
                    best_dist = dist
                    if best_len >= max_len:
                        break
                cand = prev[cand]
                depth += 1

        if best_len >= MIN_MATCH:
            emit_match(best_dist, best_len)
            end = idx + best_len
            while idx < end:
                if idx + 3 <= n:
                    key = bytes(data[idx : idx + 3])
                    prev[idx] = head.get(key, -1)
                    head[key] = idx
                idx += 1
        else:
            emit_literal(data[idx])
            if idx + 3 <= n:
                key = bytes(data[idx : idx + 3])
                prev[idx] = head.get(key, -1)
                head[key] = idx
            idx += 1

    flush_group()
    out.extend(_checksum(data).to_bytes(4, "little"))
    return bytes(out)


def decompress(data: bytes, expected_size: int) -> bytes:
    """Decompress a BIS Cprs LZSS stream to exactly `expected_size` bytes.

    Direct port of `BIS.Core.Compression.LZSS.ReadLZSS` (see module
    docstring for provenance) with the unsigned (PBO, not PAA) checksum
    form. Raises `CprsError` on truncated input, a match that would
    overshoot `expected_size` (mirrors the reference's own overflow guard),
    or a checksum mismatch."""
    if expected_size < 0:
        raise CprsError(f"expected_size must be >= 0, got {expected_size}")

    text_buf = bytearray(N)
    text_buf[: N - F] = b" " * (N - F)
    r = N - F
    flags = 0
    csum = 0
    out = bytearray()
    pos = 0
    n = len(data)

    def read_byte() -> int:
        nonlocal pos
        if pos >= n:
            raise CprsError("truncated Cprs stream: ran out of input bytes")
        b = data[pos]
        pos += 1
        return b

    bytes_left = expected_size
    while bytes_left > 0:
        flags >>= 1
        if (flags & 256) == 0:
            flags = read_byte() | 0xFF00
        if flags & 1:
            c = read_byte()
            csum += c
            out.append(c)
            bytes_left -= 1
            text_buf[r] = c
            r = (r + 1) & (N - 1)
        else:
            i = read_byte()
            j = read_byte()
            i |= (j & 0xF0) << 4
            j = (j & 0x0F) + THRESHOLD
            if j + 1 > bytes_left:
                raise CprsError(
                    f"Cprs overflow: match of length {j + 1} exceeds "
                    f"{bytes_left} remaining bytes"
                )
            ii = r - i
            jj = j + ii
            while ii <= jj:
                c = text_buf[ii & (N - 1)]
                csum += c
                out.append(c)
                bytes_left -= 1
                text_buf[r] = c
                r = (r + 1) & (N - 1)
                ii += 1

    if pos + 4 > n:
        raise CprsError("truncated Cprs stream: missing 4-byte trailing checksum")
    stored = int.from_bytes(data[pos : pos + 4], "little", signed=False)
    pos += 4
    if (csum & 0xFFFFFFFF) != stored:
        raise CprsError(
            f"Cprs checksum mismatch: computed 0x{csum & 0xFFFFFFFF:08x}, "
            f"stored 0x{stored:08x}"
        )

    return bytes(out)
