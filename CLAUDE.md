# CoCo BASIC programs

Programs for the Tandy Color Computer 1 in Extended Color BASIC. They run on a MiSTer FPGA CoCo core from `.DSK` disk images.

## Target
- CoCo 1 with Extended Color BASIC plus Disk BASIC, 32K or more of RAM. Graphics programs use `PCLEAR 8`, which takes 12K.
- They're tested on MiSTer: copy the `.DSK` to the SD card, mount it in drive 0 from the OSD (F12), then type `RUN"CUBE"`.

## Files
- `CUBE.BAS`: a wireframe cube rotating in PMODE 4 (256x192, 2 colors). It's double-buffered, so there's no flicker. It works on MiSTer.
- `make_dsk.py`: builds a 35-track DECB disk image from ASCII `.BAS` files. It turns LF line endings into CR, marks each file as an ASCII BASIC program, and fills in the FAT and directory. ToolShed `decb` isn't installed, so use this script.
  ```
  python3 make_dsk.py CUBE.DSK CUBE.BAS [MORE.BAS ...]
  ```
  `.DSK` files are build output and are gitignored.
- `deploy.sh`: builds `CUBE.DSK` and copies it onto the MiSTer SD card, overwriting the one there.
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

## Color BASIC gotchas
- Only the first 2 characters of a variable name count. For example, `PG` and `PAGE` are the same variable, so pick names that are unique in their first 2 letters.
- Variable names can't contain keywords such as `TO`, `IF`, `ON`, `OR`, `FN` or `AND`, even inside a longer name.
- The file is saved as ASCII: uppercase, one numbered line each, CR line endings on disk. `make_dsk.py` handles the line endings.
- `POKE 65495,0` doubles the CPU speed, but it isn't reliable on every CoCo 1 and it breaks cassette and disk I/O. `POKE 65494,0` restores normal speed.

## Ideas not done yet
Hide the back faces, add more frames, add other shapes, and let the arrow keys control direction.
