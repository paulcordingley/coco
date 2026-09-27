#!/bin/bash
# Build CUBE.DSK from CUBE.BAS and copy it to the MiSTer SD card.
# Usage: ./deploy.sh [destination-dir]
set -euo pipefail
cd "$(dirname "$0")"

DEST="${1:-/Volumes/sdcard/games/COCO3/LOCAL}"

if [ ! -d "$DEST" ]; then
    echo "Destination not found: $DEST (is the SD card mounted?)" >&2
    exit 1
fi

python3 make_dsk.py CUBE.DSK CUBE.BAS
cp CUBE.DSK "$DEST/CUBE.DSK"
echo "Deployed CUBE.DSK to $DEST"
