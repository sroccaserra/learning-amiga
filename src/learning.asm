;;
; vim: set syntax=asm68k:tabstop=8
;
; Learning the Amiga system
;
; This code draws a horizontal copperbar moving across the screen.
;
; Watching this gentle tutorial series:
; - <https://www.youtube.com/watch?v=p83QUZ1-P10&list=PLc3ltHgmiidpK-s0eP5hTKJnjdTHz0_bW>


********************************************************************************
ABSEXECBASE     equ             4       ; base of exec.library

INTENAR         equ             $dff01c
COP1LCH         equ             $dff080
INTENA          equ             $dff09a
VPOSR           equ             $dff004
VHPOSR          equ             $dff006
********************************************************************************

;        ORG     $20000
;        LOAD    $20000
;        JUMPPTR init

init:
        move.l  ABSEXECBASE,a6  ; preparing call to oldOpenLibrary: move execbase to a6
        clr.l   d0
        move.l  #gfxname,a1
        jsr     -408(a6)        ; call oldOpenLibrary: d0 = oldOpenLibrary(a1,d0) (relative address to exec.library)
        move.l  d0,a1           ; move result to a1
        move.l  38(a1),d4       ; save the original copper pointer to d4
        jsr     -414(a6)        ; call closelibrary()

        move    #$ac,d7         ; start y position of copperbar
        move    #1,d6           ; y increment
        move    INTENAR,d0      ; save interupt bits state
        move    d0,oldintena
        move    #$7fff,INTENA   ; disable all bits in INTENA

        move.l  #copper,COP1LCH ; Point the copper pointer to the copper list

********************************************************************************
mainloop:
waitframe1:
        btst    #0,VPOSR+1      ; wait for most significant bit of vpos (V8) to be zero (frame flop)
        bne     waitframe1
        cmp.b   #$2a,VHPOSR     ; wait for least significant bits of vpos (V7-V0) to equal #$2c
        bne     waitframe1
waitframe2:
        cmp.b   #$2a,VHPOSR     ; loop is too fast, wait until we leave that scanline
        beq     waitframe2

;------ Frame loop start ------

        add     d6,d7           ; increment y position of copperbar

        cmp.b   #$f0,d7
        blo     ok1             ; is the copper bar lower than #$f0?
        neg     d6              ; if not, negate increment (bounce on the bottom)
ok1:

        cmp.b   #$40,d7
        bhi     ok2
        neg     d6              ; same idea, but instead bounce on the top (line #$40)
ok2:

        move.l  #copperbar,a0   ; store copperbar address (in copper list) to a0
        move    d7,d0
        moveq   #6-1,d1
.loop:
        move.b  d0,(a0)         ; write current line vpos to copper list
        add     #1,d0           ; compute next line vpos
        add     #8,a0           ; compute next copper list address
        dbf     d1,.loop

;------ Frame loop end --------

        btst    #6,$bfe001      ; is mouse button pressed?
        bne     mainloop
********************************************************************************

exit:
        move.l  d4,COP1LCH              ; restore original copper pointer
        or      #$c000,oldintena
        move    oldintena,INTENA        ; restore initial INTENA bits
        rts

        CNOP    0,4
oldintena:      dc.w    0

gfxname:
        dc.b 'graphics.library',0

********************************************************************************
        SECTION tut,DATA_C      ; Allocate this section in chip memory, required by the copper
copper:
        dc.w    $1fc,   $0000   ; Slow fetch mode for AGA compatibility
        dc.w    $100,   $0200   ; Turn off all the bitplanes (with color burst = on, for Amiga 1000)

        dc.w    $180,   $349    ; set background color
        dc.w    $2b07,  $fffe   ; wait for screen position
        dc.w    $180,   $56c
        dc.w    $2c07,  $fffe
        dc.w    $180,   $113

copperbar:
        dc.w    $8007,  $fffe   ; Beginning of 5 lines copper bar
        dc.w    $180,   $055
        dc.w    $8107,  $fffe
        dc.w    $180,   $0aa
        dc.w    $8207,  $fffe
        dc.w    $180,   $0ff
        dc.w    $8307,  $fffe
        dc.w    $180,   $0aa
        dc.w    $8407,  $fffe
        dc.w    $180,   $055

        dc.w    $8107,  $fffe   ; Restore color on next line position
        dc.w    $180,   $113

        dc.w    $ffdf,  $fffe   ; wait past the first half of the screen (we have only 8 bits to express vpos here)
        dc.w    $2c07,  $fffe
        dc.w    $180,   $56c
        dc.w    $2d07,  $fffe
        dc.w    $180,   $349

        dc.w    $ffff,  $fffe   ; End of copper list (wait for impossible position $ffff)
