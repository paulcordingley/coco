*******************************************************************
* CUBE.ASM -- draws one frame of the wireframe cube into a PMODE 4
* buffer.  Loaded with LOADM"CUBE" and called with EXEC from a small
* BASIC wrapper that does PCLEAR/PMODE/SCREEN/keyboard handling.
*
* Before each EXEC, the wrapper pokes:
*   PARAMF     = frame number, 0-35
*   PARAMADR   = the current PMODE page's start address (from
*                PEEK(&HBA)*256+PEEK(&HBB), the ROM's BEGGRP pointer),
*                high byte first, low byte second (POKE PARAMADR,H
*                then POKE PARAMADR+1,L)
*
* This routine draws the 12 cube edges for that frame directly into
* the PMODE 4 (256x192, 1bpp, 32 bytes/row) buffer at PARAMADR, using
* vertex screen positions precomputed offline (same math as CUBE.BAS)
* and stored in VXTAB/VYTAB.  It does not touch any SAM/PIA hardware
* registers -- the wrapper's PMODE/SCREEN statements own the video
* mode and page flip, and its INKEY$ loop owns the keyboard/speed
* toggle, exactly as in CUBE.BAS.
*******************************************************************

        org     $6E00

START   lda     PARAMF          ; A = frame number (0-35)
        ldb     #8
        mul                     ; D = frame*8 (max 280, needs 16 bits)
        std     ROWBASE

        ldy     #EDGES          ; Y -> edge vertex-index pairs
        lda     #12
        sta     ECNT

EDGELP  ldx     ROWBASE
        ldb     ,y+             ; B = vertex index of point 0
        abx                     ; X = ROWBASE + index0
        lda     VXTAB,x
        sta     X0V
        lda     VYTAB,x
        sta     Y0V

        ldx     ROWBASE
        ldb     ,y+             ; B = vertex index of point 1
        abx                     ; X = ROWBASE + index1
        lda     VXTAB,x
        sta     X1V
        lda     VYTAB,x
        sta     Y1V

        jsr     LINE

        dec     ECNT
        bne     EDGELP
        rts

*******************************************************************
* LINE -- Bresenham's algorithm, plots from (X0V,Y0V) to (X1V,Y1V)
* into the PMODE 4 buffer at PARAMADR.  Coordinates are 0-255/0-191;
* all delta/error math is done as signed 16-bit so a full-width
* coordinate difference (up to +-255) can never overflow a byte.
*******************************************************************

LINE    clra
        ldb     X1V
        std     T1              ; T1 = 0:x1 (zero-extended)
        clra
        ldb     X0V
        std     T2              ; T2 = 0:x0
        ldd     T1
        subd    T2              ; D = x1-x0, signed, -255..255
        bpl     LSXPOS
        ldb     #$FF
        stb     SX              ; SX = -1
        coma
        comb
        addd    #1
        std     DX              ; DX = |x1-x0|
        bra     LDONEX
LSXPOS  ldb     #1
        stb     SX              ; SX = +1
        std     DX              ; DX = |x1-x0|
LDONEX

        clra
        ldb     Y1V
        std     T1
        clra
        ldb     Y0V
        std     T2
        ldd     T1
        subd    T2              ; D = y1-y0, signed, -255..255
        bpl     LSYPOS
        ldb     #$FF
        stb     SY              ; SY = -1
        std     DY              ; DY = y1-y0 = -|y1-y0| already
        bra     LDONEY
LSYPOS  ldb     #1
        stb     SY              ; SY = +1
        coma
        comb
        addd    #1
        std     DY              ; DY = -(y1-y0) = -|y1-y0|
LDONEY

        ldd     DX
        addd    DY
        std     ERR             ; err = dx + dy  (dy already <= 0)

PLOOP   bsr     PLOT

        ldb     X0V
        cmpb    X1V
        bne     PCONT
        ldb     Y0V
        cmpb    Y1V
        beq     PDONE

PCONT   ldd     ERR
        aslb
        rola                    ; D = e2 = 2*err
        std     E2
        cmpd    DY
        blt     SKIPX           ; if e2 < dy, don't step x
        ldd     ERR
        addd    DY
        std     ERR
        ldb     X0V
        addb    SX
        stb     X0V
SKIPX   ldd     E2
        cmpd    DX
        bgt     SKIPY           ; if e2 > dx, don't step y
        ldd     ERR
        addd    DX
        std     ERR
        ldb     Y0V
        addb    SY
        stb     Y0V
SKIPY   bra     PLOOP

PDONE   rts

*******************************************************************
* PLOT -- sets the pixel at (X0V,Y0V) in the buffer at PARAMADR.
* Byte address = PARAMADR + y*32 + x/8 ; bit = BITTAB[x mod 8],
* MSB (bit 7) is the leftmost pixel of the byte.
*******************************************************************

PLOT    lda     Y0V
        ldb     #32
        mul                     ; D = y*32
        addd    PARAMADR
        std     PPTR            ; PPTR = row start address

        ldb     X0V
        lsrb
        lsrb
        lsrb                    ; B = x/8
        clra
        addd    PPTR
        std     PPTR            ; PPTR = byte address of the pixel

        ldb     X0V
        andb    #7
        ldx     #BITTAB
        abx                     ; X = BITTAB + (x mod 8)
        lda     ,x              ; A = bit mask for this pixel
        ldx     PPTR
        ora     ,x              ; A = mask OR current byte
        sta     ,x              ; write it back
        rts

BITTAB  fcb     $80,$40,$20,$10,$08,$04,$02,$01

*******************************************************************
* Parameters (poked by BASIC before each EXEC)
*******************************************************************

PARAMF  fcb     0
PARAMADR fdb    0

*******************************************************************
* Working storage
*******************************************************************

ROWBASE fdb     0
ECNT    fcb     0
X0V     fcb     0
Y0V     fcb     0
X1V     fcb     0
Y1V     fcb     0
SX      fcb     0
SY      fcb     0
DX      fdb     0
DY      fdb     0
ERR     fdb     0
E2      fdb     0
T1      fdb     0
T2      fdb     0
PPTR    fdb     0

*******************************************************************
* Precomputed vertex screen positions (36 frames x 8 vertices) and
* the 12 cube edges, generated offline with the same rotation/
* projection math as CUBE.BAS.  See gen_tables.py.
*******************************************************************

        include "tables.inc"

        end     START
