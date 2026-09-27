#!/usr/bin/env python3
"""Build a 35-track Disk Extended Color BASIC (DECB) .DSK image containing
ASCII BASIC programs.  Usage: make_dsk.py OUT.DSK FILE.BAS [FILE2.BAS ...]"""
import os
import sys

TRACKS, SECTORS, SECSIZE = 35, 18, 256
DIR_TRACK = 17
GRANULES = 68
SECS_PER_GRAN = 9


def offset(track, sector):
    return (track * SECTORS + sector - 1) * SECSIZE


def granule_start(g):
    track = g // 2
    if track >= DIR_TRACK:
        track += 1
    return offset(track, (g % 2) * SECS_PER_GRAN + 1)


def main():
    out, files = sys.argv[1], sys.argv[2:]
    img = bytearray(b"\xff" * TRACKS * SECTORS * SECSIZE)
    fat = bytearray(b"\xff" * GRANULES)
    free = [g for g in range(GRANULES)]
    dir_off = offset(DIR_TRACK, 3)

    for n, path in enumerate(files):
        data = open(path, "rb").read().replace(b"\r\n", b"\n").replace(b"\n", b"\r")
        base, ext = os.path.splitext(os.path.basename(path).upper())
        name = base[:8].ljust(8).encode()
        ext = (ext[1:] or "BAS")[:3].ljust(3).encode()

        nsec = max(1, -(-len(data) // SECSIZE))
        ngran = -(-nsec // SECS_PER_GRAN)
        if ngran > len(free):
            sys.exit("disk full")
        grans, free = free[:ngran], free[ngran:]
        for i, g in enumerate(grans):
            chunk = data[i * SECS_PER_GRAN * SECSIZE:(i + 1) * SECS_PER_GRAN * SECSIZE]
            s = granule_start(g)
            img[s:s + len(chunk)] = chunk
            fat[g] = grans[i + 1] if i + 1 < len(grans) else 0xC0 + (nsec - i * SECS_PER_GRAN)
        last_bytes = len(data) - (nsec - 1) * SECSIZE

        entry = bytearray(32)
        entry[0:8] = name
        entry[8:11] = ext
        entry[11] = 0x00          # file type: BASIC program
        entry[12] = 0xFF          # ASCII flag
        entry[13] = grans[0]      # first granule
        entry[14:16] = last_bytes.to_bytes(2, "big")
        e = dir_off + n * 32
        img[e:e + 32] = entry
        print(f"{name.decode().strip()}.{ext.decode().strip()}: {len(data)} bytes, granules {grans}")

    fo = offset(DIR_TRACK, 2)
    img[fo:fo + SECSIZE] = fat + b"\x00" * (SECSIZE - GRANULES)
    open(out, "wb").write(img)
    print(f"wrote {out} ({len(img)} bytes)")


if __name__ == "__main__":
    main()
