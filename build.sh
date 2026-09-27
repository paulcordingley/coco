#!/bin/bash
# Build CUBE.DSK: precompute the frame tables, assemble CUBE.ASM,
# generate the BASIC wrapper that calls it, and pack everything onto
# the disk image alongside the original all-BASIC CUBE.BAS.
# Requires lwasm (lwtools): brew install lwtools
set -euo pipefail
cd "$(dirname "$0")"

python3 gen_tables.py
lwasm -b -o CUBE.BIN --symbol-dump=CUBE.SYM CUBE.ASM
python3 gen_wrapper.py CUBE.SYM CUBEASM.BAS
python3 make_dsk.py CUBE.DSK CUBE.BAS CUBEASM.BAS CUBE.BIN
