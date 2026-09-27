#!/usr/bin/env python3
"""Generate CUBEASM.BAS from CUBE.SYM (produced by `lwasm --symbol-dump`).

The BASIC wrapper owns PCLEAR/PMODE/SCREEN/keyboard, exactly like
CUBE.BAS, and pokes the frame number plus the current PMODE page's
start address (PEEK(&HBA)*256+PEEK(&HBB), the ROM's BEGGRP pointer)
into CUBE.BIN's PARAMF/PARAMADR before EXECing its line-drawing
routine. Re-run this whenever CUBE.ASM changes, since the addresses
of PARAMF/PARAMADR/START can move.
"""
import re
import sys

TEMPLATE = """10 REM ROTATING CUBE - 6809 ASSEMBLY LINE DRAWER
20 CLEAR 200,{cleartop}
30 PCLEAR 8
40 LOADM "CUBE"
50 CLS:PRINT "ROTATING CUBE (ASM)"
60 PRINT:PRINT "S=TOGGLE SPEED, OTHER KEY=EXIT"
70 PMODE 4,1:PCLS:SCREEN 1,1
80 PG=5:F=0:SP=0
90 PMODE 4,PG:PCLS
100 POKE {paramf},F
110 POKE {paramadrhi},PEEK(&HBA):POKE {paramadrlo},PEEK(&HBB)
120 EXEC {start}
130 SCREEN 1,1
140 PG=6-PG
150 K$=INKEY$:IF K$="" THEN 180 ELSE IF K$="S" OR K$="s" THEN SP=1-SP:POKE 65494+SP,0:GOTO 180 ELSE 220
180 F=F+1:IF F=36 THEN F=0
190 GOTO 90
220 POKE 65494,0:SCREEN 0,0:CLS:END
"""


def main():
    symfile, outfile = sys.argv[1], sys.argv[2]
    syms = {}
    with open(symfile) as f:
        for line in f:
            m = re.match(r"(\w+)\s+EQU\s+\$([0-9A-Fa-f]+)", line.strip())
            if m:
                syms[m.group(1)] = int(m.group(2), 16)

    start = syms["START"]
    paramf = syms["PARAMF"]
    paramadr = syms["PARAMADR"]

    text = TEMPLATE.format(
        cleartop=start - 1,
        paramf=paramf,
        paramadrhi=paramadr,
        paramadrlo=paramadr + 1,
        start=start,
    )
    with open(outfile, "w") as f:
        f.write(text)
    print(f"wrote {outfile}: START={start} PARAMF={paramf} PARAMADR={paramadr}")


if __name__ == "__main__":
    main()
