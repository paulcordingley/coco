# CoCo BASIC programs

Programs for the Tandy Color Computer 1 in Extended Color BASIC. They run on a MiSTer FPGA CoCo core from `.DSK` disk images.

## Target
- CoCo 1 with Extended Color BASIC plus Disk BASIC, 32K or more of RAM. Graphics programs use `PCLEAR 8`, which takes 12K.
- They're tested on MiSTer: copy the `.DSK` to the SD card, mount it in drive 0 from the OSD (F12), then type `RUN"CUBE"`.

## Files
- `CUBE.BAS`: a wireframe cube rotating in PMODE 4 (256x192, 2 colors). It's double-buffered, so there's no flicker. It works on MiSTer. Everything, including the per-frame rotation math, runs in BASIC.
- `CUBE.ASM` / `CUBEASM.BAS`: a faster hybrid version of the same cube. `CUBEASM.BAS` still owns `PCLEAR`/`PMODE`/`SCREEN`/keyboard, exactly like `CUBE.BAS`, but instead of a `LINE...PSET` loop it does one `EXEC` per frame into `CUBE.BIN` (assembled from `CUBE.ASM`), which draws all 12 edges directly into the packed 1bpp framebuffer. See "How the ASM version works" below.
- `gen_tables.py`: precomputes the 36-frame × 8-vertex screen positions (same rotation/projection math as `CUBE.BAS`) and the edge list, and writes them into `tables.inc` as `FCB` data for `CUBE.ASM` to include. Run automatically by `build.sh`.
- `gen_wrapper.py`: reads the addresses of `CUBE.BIN`'s `PARAMF`/`PARAMADR`/`START` symbols out of `CUBE.SYM` (from `lwasm --symbol-dump`) and writes `CUBEASM.BAS` with those addresses filled in. Re-run (via `build.sh`) any time `CUBE.ASM` changes, since those addresses can move.
- `make_dsk.py`: builds a 35-track DECB disk image from ASCII `.BAS` files and/or DECB-format `.BIN` machine-language files. `.BAS` files get LF→CR conversion and are marked as ASCII BASIC programs; `.BIN` files are written through unchanged (they already carry their own DECB load/exec preamble from `lwasm -b`) and marked as machine-language. ToolShed `decb` isn't installed, so use this script.
  ```
  python3 make_dsk.py CUBE.DSK CUBE.BAS [MORE.BAS ...] [MORE.BIN ...]
  ```
  `.DSK`, `.BIN`, `.LST`, `.SYM`, `tables.inc` and `CUBEASM.BAS` are all build output and are gitignored.
- `build.sh`: runs the full pipeline — `gen_tables.py`, `lwasm` (assembles `CUBE.ASM` to `CUBE.BIN`), `gen_wrapper.py`, then `make_dsk.py` — to produce `CUBE.DSK`. Requires `lwasm` from lwtools: `brew install lwtools`.
- `deploy.sh`: runs `build.sh` and copies `CUBE.DSK` onto the MiSTer SD card, overwriting the one there.
  ```
  ./deploy.sh [destination-dir]
  ```
  Default destination is `/Volumes/sdcard/games/COCO3/LOCAL`, where the SD card mounts on this Mac. Pass a different directory as the first argument if that mount path changes. It fails loudly if the destination doesn't exist, since that usually means the card isn't mounted.

## How CUBE.BAS works
- **Page flipping:** `PCLEAR 8` gives two PMODE 4 screens, pages 1-4 and pages 5-8. `PMODE 4,PG` only changes where BASIC draws; the display doesn't move until `SCREEN 1,1` runs. Each frame: `PMODE 4,PG:PCLS`, draw, `SCREEN 1,1` to show it, then `PG=6-PG` to switch between 1 and 5.
- **Frames worked out first:** BASIC is too slow to do the rotation math in real time. At startup it computes screen positions for 8 vertices × 36 frames, 10° apart, into `X(F,I)` and `Y(F,I)`. This takes about 20-30 seconds. The animation loop only clears the page and draws 12 lines with `LINE ... ,PSET`.
- **Rotation:** Y axis by angle A, X axis by 2A, so the 36 frames loop without a jump. Perspective is `P=S/(Z+D)` with S=90 and D=3.5, which keeps the cube inside 192 lines. The center is (128,96).
- **Data:** vertices and edges are in `DATA` lines. Changing the shape means new vertex and edge data, plus updating the array sizes and loop limits (7 for vertices, 11 for edges).
- **Speed toggle:** pressing `S` (or `s`) during the animation toggles `POKE 65495,0` (double speed) on and off, restoring `POKE 65494,0` (normal speed) each time it's turned off. Any other key exits, and exiting always restores normal speed first so disk/cassette I/O isn't left broken.
- Colors use the defaults with `SCREEN 1,1`: buff lines on black.

## How the ASM version works
- **Division of labor:** `CUBEASM.BAS` deliberately keeps all hardware setup in BASIC (`PCLEAR`, `PMODE`, `SCREEN`, `INKEY$`, the speed-toggle `POKE`s) because that's already proven to work on real hardware. `CUBE.ASM` never touches SAM/PIA registers directly — it only draws pixels into whatever buffer BASIC's `PMODE 4,PG` already selected.
- **Finding the buffer:** after `PMODE 4,PG`, the ROM's "BEGGRP" pointer at `PEEK(&HBA)*256+PEEK(&HBB)` holds the current page's start address. `CUBEASM.BAS` reads that and pokes it into `CUBE.BIN`'s `PARAMADR` (high byte then low byte) before each `EXEC`, along with the frame number into `PARAMF`.
- **Memory layout:** `CUBEASM.BAS` does `CLEAR 200,<START-1>` before `PCLEAR 8`, pinning BASIC's memory ceiling just below where `CUBE.BIN` (`ORG $6E00`) loads. `PCLEAR 8` then reserves its 12K graphics buffers below that ceiling, so BASIC, the two PMODE pages, and the ML program never overlap. `gen_wrapper.py` computes the ceiling from `CUBE.ASM`'s actual `START` address, so it stays correct if the `ORG` ever changes.
- **No runtime trig:** `CUBE.ASM` has no rotation math at all — `gen_tables.py` precomputes all 288 vertex positions offline in Python (matching `CUBE.BAS`'s formulas exactly) and embeds them as byte tables, so there's no 20-30 second precompute pause.
- **Drawing:** for each of the 12 edges, it looks up both endpoints' precomputed (X,Y) and runs an integer Bresenham line, setting bits directly in the PMODE 4 framebuffer (32 bytes/row, MSB = leftmost pixel).
- **Verification:** `CUBE.ASM` assembles cleanly with `lwasm`, and the Bresenham/table logic has been cross-checked in Python against a reference implementation for all 432 real cube edges, but it hasn't been run on real hardware or in an emulator — there was no CoCo emulator or ROM set available to test with when this was written. If it doesn't come up cleanly on MiSTer, that's the first thing to suspect.

## Color BASIC gotchas
- Only the first 2 characters of a variable name count. For example, `PG` and `PAGE` are the same variable, so pick names that are unique in their first 2 letters.
- Variable names can't contain keywords such as `TO`, `IF`, `ON`, `OR`, `FN` or `AND`, even inside a longer name.
- The file is saved as ASCII: uppercase, one numbered line each, CR line endings on disk. `make_dsk.py` handles the line endings.
- `POKE 65495,0` doubles the CPU speed, but it isn't reliable on every CoCo 1 and it breaks cassette and disk I/O. `POKE 65494,0` restores normal speed.

## Ideas not done yet
Hide the back faces, add more frames, add other shapes, and let the arrow keys control direction.
